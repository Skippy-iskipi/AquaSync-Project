const express = require('express');
const router = express.Router();
const db = require('../db/db');
const { protectRoute } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/fish');
    
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
    cb(null, 'fish-' + uniqueSuffix + ext);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    // Accept only images
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Only image files are allowed'), false);
    }
    cb(null, true);
  }
});

// Get all fish
router.get('/', protectRoute, async (req, res) => {
  try {
    // Get status from query params, default to 'active'
    const status = req.query.status || 'active';
    
    let query = 'SELECT * FROM fish_species';
    const queryParams = [];
    
    // Filter by status if provided
    if (status !== 'all') {
      query += ' WHERE status = $1';
      queryParams.push(status);
    }
    
    query += ' ORDER BY common_name';
    
    console.log('Fish query:', query);
    console.log('Query params:', queryParams);
    
    const result = await db.query(query, queryParams);
    
    console.log(`Found ${result.rows.length} fish with status '${status}'`);
    
    // Log the view action
    await db.logAdminActivity(
      req.user.id,
      'VIEW_FISH_LIST',
      `Viewed fish species list (${status})`,
      req.ip
    );
    
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching fish:', err);
    res.status(500).json({ error: 'Failed to fetch fish' });
  }
});

// Get a single fish by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      'SELECT * FROM fish_species WHERE id = $1',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Fish species not found' });
    }
    
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching fish species:', err);
    res.status(500).json({ error: 'Server error while fetching fish species' });
  }
});

// Add new fish
router.post('/', protectRoute, async (req, res) => {
  const {
    common_name,
    scientific_name,
    water_type,
    "max_size_(cm)": maxSize,
    temperament,
    "temperature_range_(°c)": tempRange,
    ph_range,
    habitat_type,
    social_behavior,
    tank_level,
    "minimum_tank_size_(l)": minTankSize,
    compatibility_notes,
    diet,
    lifespan,
    care_level,
    preferred_food,
    feeding_frequency
  } = req.body;

  try {
    // Insert new fish with active status
    const fishResult = await db.query(
      `INSERT INTO fish_species (
        common_name, scientific_name, water_type, "max_size_(cm)", 
        temperament, "temperature_range_(°c)", ph_range, habitat_type,
        social_behavior, tank_level, "minimum_tank_size_(l)", compatibility_notes,
        diet, lifespan, care_level, preferred_food, feeding_frequency, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
      RETURNING *`,
      [
        common_name, scientific_name, water_type, maxSize,
        temperament, tempRange, ph_range, habitat_type,
        social_behavior, tank_level, minTankSize, compatibility_notes,
        diet, lifespan, care_level, preferred_food, feeding_frequency, 'active'
      ]
    );

    // Log the activity
    await db.logAdminActivity(
      req.user.id,
      'ADD_FISH',
      `Added new fish: ${common_name} (${scientific_name})`,
      req.ip
    );

    res.status(201).json(fishResult.rows[0]);
  } catch (err) {
    console.error('Error adding fish:', err);
    res.status(500).json({ error: 'Failed to add fish' });
  }
});

// Update fish
router.put('/:id', protectRoute, async (req, res) => {
  const id = req.params.id;
  const {
    common_name,
    scientific_name,
    water_type,
    "max_size_(cm)": maxSize,
    temperament,
    "temperature_range_(°c)": tempRange,
    ph_range,
    habitat_type,
    social_behavior,
    tank_level,
    "minimum_tank_size_(l)": minTankSize,
    compatibility_notes,
    diet,
    lifespan,
    care_level,
    preferred_food,
    feeding_frequency
  } = req.body;

  try {
    const result = await db.query(
      `UPDATE fish_species SET 
        common_name = $1,
        scientific_name = $2,
        water_type = $3,
        "max_size_(cm)" = $4,
        temperament = $5,
        "temperature_range_(°c)" = $6,
        ph_range = $7,
        habitat_type = $8,
        social_behavior = $9,
        tank_level = $10,
        "minimum_tank_size_(l)" = $11,
        compatibility_notes = $12,
        diet = $13,
        lifespan = $14,
        care_level = $15,
        preferred_food = $16,
        feeding_frequency = $17,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $18
      RETURNING *`,
      [
        common_name, scientific_name, water_type, maxSize,
        temperament, tempRange, ph_range, habitat_type,
        social_behavior, tank_level, minTankSize, compatibility_notes,
        diet, lifespan, care_level, preferred_food, feeding_frequency,
        id
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Fish not found' });
    }

    // Log the activity
    await db.logAdminActivity(
      req.user.id,
      'UPDATE_FISH',
      `Updated fish: ${common_name} (${scientific_name})`,
      req.ip
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating fish:', err);
    res.status(500).json({ error: 'Failed to update fish' });
  }
});

// Delete fish
router.delete('/:id', protectRoute, async (req, res) => {
  const id = req.params.id;

  try {
    // Get fish details before deletion for logging
    const fishDetails = await db.query(
      'SELECT common_name, scientific_name FROM fish_species WHERE id = $1',
      [id]
    );

    if (fishDetails.rows.length === 0) {
      return res.status(404).json({ error: 'Fish not found' });
    }

    const { common_name, scientific_name } = fishDetails.rows[0];

    // Permanently delete the fish
    await db.query('DELETE FROM fish_species WHERE id = $1', [id]);

    // Log the activity
    await db.logAdminActivity(
      req.user.id,
      'DELETE_FISH',
      `Permanently deleted fish: ${common_name} (${scientific_name})`,
      req.ip
    );

    res.json({ message: 'Fish deleted successfully' });
  } catch (err) {
    console.error('Error deleting fish:', err);
    res.status(500).json({ error: 'Failed to delete fish' });
  }
});

// Update fish status (archive/unarchive)
router.patch('/:id/status', protectRoute, async (req, res) => {
  const id = req.params.id;
  const { status } = req.body;
  
  // Validate status
  if (!status || !['active', 'archived'].includes(status)) {
    return res.status(400).json({ error: 'Invalid status. Must be "active" or "archived"' });
  }
  
  try {
    // Get fish details before status update for logging
    const fishDetails = await db.query(
      'SELECT common_name, scientific_name, status FROM fish_species WHERE id = $1',
      [id]
    );

    if (fishDetails.rows.length === 0) {
      return res.status(404).json({ error: 'Fish not found' });
    }

    const { common_name, scientific_name, current_status } = fishDetails.rows[0];
    
    // If status is already set to the requested value, return early
    if (current_status === status) {
      return res.json({ 
        message: `Fish already has status: ${status}`,
        fish: fishDetails.rows[0]
      });
    }

    // Update the fish status
    const result = await db.query(
      'UPDATE fish_species SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [status, id]
    );

    // Log the activity
    const action = status === 'archived' ? 'ARCHIVE_FISH' : 'UNARCHIVE_FISH';
    const actionDesc = status === 'archived' 
      ? `Archived fish: ${common_name} (${scientific_name})`
      : `Restored fish: ${common_name} (${scientific_name})`;
      
    await db.logAdminActivity(
      req.user.id,
      action,
      actionDesc,
      req.ip
    );

    res.json({ 
      message: `Fish status updated to ${status} successfully`,
      fish: result.rows[0]
    });
  } catch (err) {
    console.error('Error updating fish status:', err);
    res.status(500).json({ error: 'Failed to update fish status' });
  }
});

module.exports = router; 