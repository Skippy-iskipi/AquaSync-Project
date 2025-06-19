const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const db = require('../db');
const { authenticateAdmin, logActivity } = require('../middleware/auth');

// Global variable to track training state
let trainingProcess = null;
let trainingState = {
  state: 'idle', // idle, training, completed, failed
  progress: 0,
  logs: [],
  metrics: {},
  epoch_history: [],
  error: null,
  started_at: null,
  dataset_id: null,
};

// Get training status
router.get('/status', authenticateAdmin, (req, res) => {
  res.json(trainingState);
});

// Start model training
router.post('/train', authenticateAdmin, async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    // Check if training is already in progress
    if (trainingProcess && trainingState.state === 'training') {
      return res.status(400).json({ error: 'Training is already in progress' });
    }
    
    await client.query('BEGIN');
    
    const { 
      dataset_id, 
      epochs = 20, 
      batch_size = 32, 
      learning_rate = 0.001, 
      validation_split = 0.2,
      augmentation = true
    } = req.body;
    
    // Validate inputs
    if (!dataset_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Dataset ID is required' });
    }
    
    // Check if dataset exists
    const datasetResult = await client.query(
      'SELECT * FROM training_datasets WHERE id = $1',
      [dataset_id]
    );
    
    if (datasetResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Dataset not found' });
    }
    
    const dataset = datasetResult.rows[0];
    
    // Create training record
    const trainingResult = await client.query(
      `INSERT INTO model_training (
        dataset_id, epochs, batch_size, learning_rate, validation_split,
        augmentation, status, admin_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id`,
      [
        dataset_id,
        epochs,
        batch_size,
        learning_rate,
        validation_split,
        augmentation,
        'in_progress',
        req.user.id
      ]
    );
    
    const trainingId = trainingResult.rows[0].id;
    
    // Log activity
    await client.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'MODEL_TRAINING_START', `Started model training with dataset: ${dataset.name}`]
    );
    
    await client.query('COMMIT');
    
    // Reset training state
    trainingState = {
      state: 'training',
      progress: 0,
      logs: [],
      metrics: {},
      epoch_history: [],
      error: null,
      started_at: new Date(),
      dataset_id: dataset_id,
      training_id: trainingId,
      dataset_name: dataset.name
    };
    
    // Start training process
    startTraining(dataset, {
      epochs,
      batch_size,
      learning_rate,
      validation_split,
      augmentation,
      trainingId
    });
    
    res.json({ message: 'Training started', training_id: trainingId });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error starting training:', err);
    res.status(500).json({ error: 'Server error while starting training' });
  } finally {
    client.release();
  }
});

// Stop training
router.post('/stop', authenticateAdmin, async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    // Check if training is in progress
    if (!trainingProcess || trainingState.state !== 'training') {
      return res.status(400).json({ error: 'No training in progress' });
    }
    
    await client.query('BEGIN');
    
    // Kill training process
    trainingProcess.kill('SIGTERM');
    trainingProcess = null;
    
    // Update training record
    await client.query(
      'UPDATE model_training SET status = $1, completed_at = NOW() WHERE id = $2',
      ['cancelled', trainingState.training_id]
    );
    
    // Log activity
    await client.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'MODEL_TRAINING_STOP', 'Stopped model training']
    );
    
    // Reset training state
    trainingState = {
      state: 'idle',
      progress: 0,
      logs: [],
      metrics: {},
      epoch_history: [],
      error: null,
      started_at: null,
      dataset_id: null
    };
    
    await client.query('COMMIT');
    res.json({ message: 'Training stopped' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error stopping training:', err);
    res.status(500).json({ error: 'Server error while stopping training' });
  } finally {
    client.release();
  }
});

// Get training history
router.get('/history', authenticateAdmin, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT mt.*, td.name as dataset_name
       FROM model_training mt
       JOIN training_datasets td ON mt.dataset_id = td.id
       ORDER BY mt.created_at DESC`,
      []
    );
    
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching training history:', err);
    res.status(500).json({ error: 'Server error while fetching training history' });
  }
});

// Get model by ID
router.get('/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT mt.*, td.name as dataset_name
       FROM model_training mt
       JOIN training_datasets td ON mt.dataset_id = td.id
       WHERE mt.id = $1`,
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Model not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching model:', err);
    res.status(500).json({ error: 'Server error while fetching model' });
  }
});

// Activate model
router.post('/:id/activate', authenticateAdmin, async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    
    // Check if model exists
    const checkResult = await client.query(
      'SELECT * FROM model_training WHERE id = $1',
      [id]
    );
    
    if (checkResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Model not found' });
    }
    
    const model = checkResult.rows[0];
    
    if (model.status !== 'completed') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Can only activate completed models' });
    }
    
    // Deactivate all models
    await client.query(
      'UPDATE model_training SET active = false'
    );
    
    // Activate selected model
    await client.query(
      'UPDATE model_training SET active = true WHERE id = $1',
      [id]
    );
    
    // Update model path in configuration
    await client.query(
      'UPDATE system_config SET value = $1 WHERE key = $2',
      [model.model_path, 'active_model_path']
    );
    
    // Log activity
    await client.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'MODEL_ACTIVATE', `Activated model: ${id}`]
    );
    
    await client.query('COMMIT');
    res.json({ message: 'Model activated successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error activating model:', err);
    res.status(500).json({ error: 'Server error while activating model' });
  } finally {
    client.release();
  }
});

// Helper function to start training process
function startTraining(dataset, options) {
  const { epochs, batch_size, learning_rate, validation_split, augmentation, trainingId } = options;
  
  // Path to Python training script
  const scriptPath = path.join(__dirname, '../scripts/train_model.py');
  
  // Ensure the script exists
  if (!fs.existsSync(scriptPath)) {
    trainingState.state = 'failed';
    trainingState.error = 'Training script not found';
    return;
  }
  
  // Training output directory
  const outputDir = path.join(__dirname, '../models', `model-${trainingId}`);
  
  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  // Create argument list
  const args = [
    scriptPath,
    '--dataset_path', dataset.extract_path,
    '--output_dir', outputDir,
    '--epochs', epochs.toString(),
    '--batch_size', batch_size.toString(),
    '--learning_rate', learning_rate.toString(),
    '--validation_split', validation_split.toString(),
  ];
  
  if (augmentation) {
    args.push('--augmentation');
  }
  
  // Spawn Python process
  trainingProcess = spawn('python', args);
  
  // Handle process output
  trainingProcess.stdout.on('data', (data) => {
    const output = data.toString().trim();
    console.log('Training output:', output);
    trainingState.logs.push(output);
    
    // Parse progress information
    if (output.startsWith('PROGRESS:')) {
      const progressInfo = output.substring(9).trim();
      const [progress, currentEpoch, totalEpochs] = progressInfo.split(',');
      trainingState.progress = parseInt(progress);
    }
    
    // Parse metrics information
    if (output.startsWith('METRICS:')) {
      const metricsInfo = output.substring(8).trim();
      try {
        const metrics = JSON.parse(metricsInfo);
        trainingState.metrics = metrics;
      } catch (e) {
        console.error('Error parsing metrics:', e);
      }
    }
    
    // Parse epoch history
    if (output.startsWith('EPOCH:')) {
      const epochInfo = output.substring(6).trim();
      try {
        const epochData = JSON.parse(epochInfo);
        trainingState.epoch_history.push(epochData);
      } catch (e) {
        console.error('Error parsing epoch data:', e);
      }
    }
  });
  
  trainingProcess.stderr.on('data', (data) => {
    const error = data.toString().trim();
    console.error('Training error:', error);
    trainingState.logs.push(`ERROR: ${error}`);
  });
  
  trainingProcess.on('close', async (code) => {
    console.log(`Training process exited with code ${code}`);
    
    const client = await db.pool.connect();
    
    try {
      await client.query('BEGIN');
      
      if (code === 0) {
        // Training completed successfully
        trainingState.state = 'completed';
        trainingState.progress = 100;
        
        // Update model record with results
        await client.query(
          `UPDATE model_training SET 
           status = 'completed', 
           completed_at = NOW(),
           model_path = $1,
           accuracy = $2,
           val_accuracy = $3,
           loss = $4,
           val_loss = $5,
           class_count = $6,
           class_accuracy = $7,
           confusion_matrix = $8
           WHERE id = $9`,
          [
            path.join(outputDir, 'model.h5'),
            trainingState.metrics.accuracy || 0,
            trainingState.metrics.val_accuracy || 0,
            trainingState.metrics.loss || 0,
            trainingState.metrics.val_loss || 0,
            trainingState.metrics.class_count || 0,
            JSON.stringify(trainingState.metrics.class_accuracy || []),
            JSON.stringify(trainingState.metrics.confusion_matrix || []),
            trainingId
          ]
        );
        
        // Log activity
        await client.query(
          'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
          [1, 'MODEL_TRAINING_COMPLETE', `Model training completed: ${trainingId}`]
        );
      } else {
        // Training failed
        trainingState.state = 'failed';
        trainingState.error = `Training process exited with code ${code}`;
        
        // Update model record
        await client.query(
          'UPDATE model_training SET status = $1, completed_at = NOW(), error_message = $2 WHERE id = $3',
          ['failed', trainingState.error, trainingId]
        );
        
        // Log activity
        await client.query(
          'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
          [1, 'MODEL_TRAINING_FAILED', `Model training failed: ${trainingId}`]
        );
      }
      
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('Error updating training record:', err);
    } finally {
      client.release();
      trainingProcess = null;
    }
  });
}

module.exports = router; 