const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const AdmZip = require('adm-zip');
const db = require('../db');
const { authenticateAdmin, logActivity } = require('../middleware/auth');

// Configure multer for dataset uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/datasets');
    
    // Create directory if it doesn't exist
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Create unique filename with original extension
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'dataset-' + uniqueSuffix + ext);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 500 * 1024 * 1024 }, // 500MB limit
  fileFilter: (req, file, cb) => {
    // Accept only zip files
    if (file.mimetype !== 'application/zip' && file.mimetype !== 'application/x-zip-compressed') {
      return cb(new Error('Only ZIP files are allowed'), false);
    }
    cb(null, true);
  }
});

// Get all datasets
router.get('/', authenticateAdmin, async (req, res) => {
  try {
    // Check if table exists
    const tableCheck = await db.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'datasets'
      );
    `);
    
    if (!tableCheck.rows[0].exists) {
      return res.status(404).json({ 
        error: 'Datasets table not found',
        datasets: []
      });
    }
    
    const result = await db.query(
      'SELECT * FROM datasets ORDER BY created_at DESC',
      []
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching datasets:', err);
    res.status(500).json({ 
      error: 'Server error while fetching datasets',
      datasets: [] 
    });
  }
});

// Upload new dataset
router.post('/upload', authenticateAdmin, upload.single('dataset'), async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    await client.query('BEGIN');
    
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const zipFilePath = req.file.path;
    const datasetName = req.file.originalname.replace(/\.[^/.]+$/, ''); // Remove file extension
    const extractDir = path.join(__dirname, '../uploads/datasets/extracted', datasetName + '-' + Date.now());
    
    // Create extraction directory
    if (!fs.existsSync(extractDir)) {
      fs.mkdirSync(extractDir, { recursive: true });
    }
    
    // Extract ZIP file
    const zip = new AdmZip(zipFilePath);
    zip.extractAllTo(extractDir, true);
    
    // Analyze dataset
    const classDistribution = [];
    let totalImages = 0;
    let classCount = 0;
    
    // Read directories (each directory is a class)
    const items = fs.readdirSync(extractDir);
    for (const item of items) {
      const itemPath = path.join(extractDir, item);
      const stats = fs.statSync(itemPath);
      
      if (stats.isDirectory()) {
        // Count images in directory
        const images = fs.readdirSync(itemPath).filter(file => 
          ['.jpg', '.jpeg', '.png'].includes(path.extname(file).toLowerCase())
        );
        
        if (images.length > 0) {
          classCount++;
          totalImages += images.length;
          classDistribution.push({
            species: item,
            count: images.length
          });
        }
      }
    }
    
    // Insert dataset record
    const insertResult = await client.query(
      `INSERT INTO datasets (
        name, description, file_path, file_size, file_type,
        class_count, image_count, uploaded_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *`,
      [
        datasetName,
        `Extracted to ${extractDir}`,
        zipFilePath,
        req.file.size,
        'zip',
        classCount,
        totalImages,
        req.user.id
      ]
    );
    
    const dataset = insertResult.rows[0];
    
    await client.query('COMMIT');
    res.status(201).json(dataset);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error uploading dataset:', err);
    res.status(500).json({ error: 'Server error while uploading dataset' });
  } finally {
    client.release();
  }
});

// Get dataset by ID
router.get('/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      'SELECT * FROM datasets WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Dataset not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching dataset:', err);
    res.status(500).json({ error: 'Server error while fetching dataset' });
  }
});

// Activate dataset (set as current active dataset)
router.post('/:id/activate', authenticateAdmin, async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    
    // Check if dataset exists
    const checkResult = await client.query(
      'SELECT * FROM datasets WHERE id = $1',
      [id]
    );
    
    if (checkResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Dataset not found' });
    }
    
    const dataset = checkResult.rows[0];
    
    // Deactivate all datasets
    await client.query(
      'UPDATE datasets SET active = false'
    );
    
    // Activate selected dataset
    await client.query(
      'UPDATE datasets SET active = true WHERE id = $1',
      [id]
    );
    
    // Update dataset path in configuration
    await client.query(
      'UPDATE system_config SET value = $1 WHERE key = $2',
      [dataset.extract_path, 'active_dataset_path']
    );
    
    // Log activity
    await client.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'DATASET_ACTIVATE', `Activated dataset: ${dataset.name}`]
    );
    
    await client.query('COMMIT');
    res.json({ message: 'Dataset activated successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error activating dataset:', err);
    res.status(500).json({ error: 'Server error while activating dataset' });
  } finally {
    client.release();
  }
});

// Delete dataset
router.delete('/:id', authenticateAdmin, async (req, res) => {
  const client = await db.pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { id } = req.params;
    
    // Check if dataset exists
    const checkResult = await client.query(
      'SELECT * FROM datasets WHERE id = $1',
      [id]
    );
    
    if (checkResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Dataset not found' });
    }
    
    const dataset = checkResult.rows[0];
    
    if (dataset.active) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Cannot delete active dataset' });
    }
    
    // Delete files
    if (fs.existsSync(dataset.file_path)) {
      fs.unlinkSync(dataset.file_path);
    }
    
    if (fs.existsSync(dataset.extract_path)) {
      fs.rmdirSync(dataset.extract_path, { recursive: true });
    }
    
    // Delete dataset record
    await client.query('DELETE FROM datasets WHERE id = $1', [id]);
    
    // Log activity
    await client.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'DATASET_DELETE', `Deleted dataset: ${dataset.name}`]
    );
    
    await client.query('COMMIT');
    res.json({ message: 'Dataset deleted successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error deleting dataset:', err);
    res.status(500).json({ error: 'Server error while deleting dataset' });
  } finally {
    client.release();
  }
});

module.exports = router; 