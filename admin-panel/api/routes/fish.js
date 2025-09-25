const express = require('express');
const { body, validationResult } = require('express-validator');
const supabase = require('../config/supabase');
const { authenticateAdmin } = require('../middleware/auth');

const router = express.Router();

// Get all fish species with pagination (temporary - no auth for development)
router.get('/', async (req, res) => {
  try {
    const { search = '' } = req.query;

    let query = supabase
      .from('fish_species')
      .select(`
        id,
        common_name,
        scientific_name,
        "max_size_(cm)",
        temperament,
        water_type,
        ph_range,
        social_behavior,
        "minimum_tank_size_(l)",
        temperature_range,
        diet,
        lifespan,
        preferred_food,
        feeding_frequency,
        bioload,
        portion_grams,
        feeding_notes,
        active
      `)
      .order('common_name', { ascending: true });

    // Add search filter if provided
    if (search) {
      query = query.or(`common_name.ilike.%${search}%,scientific_name.ilike.%${search}%`);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Fish fetch error:', error);
      // If active column doesn't exist, try without it
      if (error.message && error.message.includes('active')) {
        console.log('Active column not found, fetching without it...');
        const fallbackQuery = supabase
          .from('fish_species')
          .select(`
            id,
            common_name,
            scientific_name,
            "max_size_(cm)",
            temperament,
            water_type,
            ph_range,
            social_behavior,
            "minimum_tank_size_(l)",
            temperature_range,
            diet,
            lifespan,
            preferred_food,
            feeding_frequency,
            bioload,
            portion_grams,
            feeding_notes
          `)
          .order('common_name', { ascending: true });
        
        const { data: fallbackData, error: fallbackError } = await fallbackQuery;
        if (fallbackError) throw fallbackError;
        
        // Add active: true to all fish if column doesn't exist
        const fishWithActive = (fallbackData || []).map(fish => ({
          ...fish,
          active: true
        }));
        
        return res.json(fishWithActive);
      }
      throw error;
    }

    // Add active: true to fish that don't have the active field
    const fishWithActive = (data || []).map(fish => ({
      ...fish,
      active: fish.active !== undefined ? fish.active : true
    }));

    res.json(fishWithActive);
  } catch (error) {
    console.error('Fish fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch fish species' });
  }
});

// Get single fish species by ID
router.get('/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from('fish_species')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;

    if (!data) {
      return res.status(404).json({ message: 'Fish species not found' });
    }

    res.json(data);
  } catch (error) {
    console.error('Fish fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch fish species' });
  }
});

// Create new fish species (temporary - no auth for development)
router.post('/', [
  body('common_name').notEmpty().withMessage('Common name is required'),
  body('water_type').isIn(['Freshwater', 'Saltwater', 'Brackish']).withMessage('Invalid water type'),
  body('max_size_(cm)').optional().isFloat({ min: 0 }).withMessage('Max size must be a positive number'),
  body('portion_grams').optional().isFloat({ min: 0 }).withMessage('Portion must be a positive number'),
  body('minimum_tank_size_(l)').optional().isInt({ min: 0 }).withMessage('Tank size must be a positive integer')
], async (req, res) => {
  try {
    console.log('POST /api/fish - Request body:', req.body);
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('Validation errors:', errors.array());
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    const fishData = {
      common_name: req.body.common_name,
      scientific_name: req.body.scientific_name,
      'max_size_(cm)': req.body['max_size_(cm)'],
      temperament: req.body.temperament,
      water_type: req.body.water_type,
      ph_range: req.body.ph_range,
      social_behavior: req.body.social_behavior,
      tank_level: req.body.tank_level,
      'minimum_tank_size_(l)': req.body['minimum_tank_size_(l)'],
      diet: req.body.diet,
      lifespan: req.body.lifespan,
      care_level: req.body.care_level,
      preferred_food: req.body.preferred_food,
      feeding_frequency: req.body.feeding_frequency,
      bioload: req.body.bioload,
      portion_grams: req.body.portion_grams,
      feeding_notes: req.body.feeding_notes,
      description: req.body.description,
      overfeeding_risks: req.body.overfeeding_risks,
      temperature_range: req.body.temperature_range
    };

    console.log('Inserting fish data:', fishData);
    
    const { data, error } = await supabase
      .from('fish_species')
      .insert([fishData])
      .select()
      .single();

    if (error) {
      console.error('Supabase insertion error:', error);
      throw error;
    }

    console.log('Fish created successfully:', data);
    res.status(201).json({
      message: 'Fish species created successfully',
      data
    });
  } catch (error) {
    console.error('Fish creation error:', error);
    console.error('Error details:', {
      code: error.code,
      message: error.message,
      details: error.details,
      hint: error.hint
    });
    
    if (error.code === '23505') { // Unique constraint violation
      res.status(409).json({ message: 'Fish species with this name already exists' });
    } else {
      res.status(500).json({ 
        message: 'Failed to create fish species',
        error: error.message || 'Unknown database error'
      });
    }
  }
});

// Update fish species (temporary - no auth for development)
router.put('/:id', [
  body('common_name').optional().notEmpty().withMessage('Common name cannot be empty'),
  body('water_type').optional().isIn(['Freshwater', 'Saltwater', 'Brackish']).withMessage('Invalid water type'),
  body('max_size_(cm)').optional().isFloat({ min: 0 }).withMessage('Max size must be a positive number'),
  body('portion_grams').optional().isFloat({ min: 0 }).withMessage('Portion must be a positive number'),
  body('minimum_tank_size_(l)').optional().isInt({ min: 0 }).withMessage('Tank size must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    const { id } = req.params;
    const updateData = {
      common_name: req.body.common_name,
      scientific_name: req.body.scientific_name,
      'max_size_(cm)': req.body['max_size_(cm)'],
      temperament: req.body.temperament,
      water_type: req.body.water_type,
      ph_range: req.body.ph_range,
      social_behavior: req.body.social_behavior,
      tank_level: req.body.tank_level,
      'minimum_tank_size_(l)': req.body['minimum_tank_size_(l)'],
      diet: req.body.diet,
      lifespan: req.body.lifespan,
      care_level: req.body.care_level,
      preferred_food: req.body.preferred_food,
      feeding_frequency: req.body.feeding_frequency,
      bioload: req.body.bioload,
      portion_grams: req.body.portion_grams,
      feeding_notes: req.body.feeding_notes,
      description: req.body.description,
      overfeeding_risks: req.body.overfeeding_risks,
      temperature_range: req.body.temperature_range
    };

    // Remove undefined values
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });

    const { data, error } = await supabase
      .from('fish_species')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    if (!data) {
      return res.status(404).json({ message: 'Fish species not found' });
    }

    res.json({
      message: 'Fish species updated successfully',
      data
    });
  } catch (error) {
    console.error('Fish update error:', error);
    res.status(500).json({ message: 'Failed to update fish species' });
  }
});

// Delete fish species (temporary - no auth for development)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Skip tank check for now since tank_fish table may not exist
    // TODO: Re-enable when tank system is implemented

    const { error } = await supabase
      .from('fish_species')
      .delete()
      .eq('id', id);

    if (error) throw error;

    res.json({ message: 'Fish species deleted successfully' });
  } catch (error) {
    console.error('Fish deletion error:', error);
    res.status(500).json({ message: 'Failed to delete fish species' });
  }
});

// Toggle fish species status (activate/deactivate)
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { active } = req.body;
    const token = req.header('Authorization')?.replace('Bearer ', '');

    console.log('Fish status update request:', { id, active, token: token ? 'Present' : 'Missing' });

    if (typeof active !== 'boolean') {
      return res.status(400).json({ message: 'Active status must be a boolean value' });
    }

    console.log(`Updating fish ${id} status to: ${active}`);

    // First, try to update with active column
    let updateData = { 
      active: active,
      updated_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('fish_species')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Fish status update error:', error);
      
      // If active column doesn't exist, return a helpful error
      if (error.message && error.message.includes('active')) {
        return res.status(400).json({ 
          message: 'Active column does not exist in fish_species table. Please run the SQL script to add the active column first.',
          error: 'MISSING_ACTIVE_COLUMN',
          details: 'Run the SQL script: add_active_column_to_fish_species.sql'
        });
      }
      
      throw error;
    }

    if (!data) {
      return res.status(404).json({ message: 'Fish species not found' });
    }

    console.log(`Fish ${id} status updated successfully to: ${active}`);
    res.json({
      message: `Fish species ${active ? 'activated' : 'deactivated'} successfully`,
      data
    });
  } catch (error) {
    console.error('Fish status update error:', error);
    res.status(500).json({ 
      message: `Failed to ${req.body.active ? 'activate' : 'deactivate'} fish species`,
      error: error.message 
    });
  }
});

// Bulk upload fish species
router.post('/bulk', async (req, res) => {
  try {
    const { fish } = req.body;

    if (!Array.isArray(fish) || fish.length === 0) {
      return res.status(400).json({ message: 'Fish array is required' });
    }

    // Validate each fish entry
    const validationErrors = [];
    const validFish = [];

    fish.forEach((fishData, index) => {
      const errors = [];
      const rowNumber = index + 1;
      
      // Check for completely empty rows
      const hasAnyData = Object.values(fishData).some(value => 
        value !== null && value !== undefined && value.toString().trim() !== ''
      );
      
      if (!hasAnyData) {
        validationErrors.push(`Row ${rowNumber}: Empty row detected - skipping`);
        return; // Skip this row entirely
      }
      
      // Required fields validation
      const requiredFields = [
        'common_name', 'scientific_name', 'water_type', 'temperament', 
        'diet', 'max_size_(cm)', 'minimum_tank_size_(l)', 'ph_range',
        'temperature_range', 'social_behavior', 'lifespan', 'preferred_food',
        'feeding_frequency', 'bioload', 'portion_grams', 'feeding_notes'
      ];

      requiredFields.forEach(field => {
        const value = fishData[field];
        
        // Check for null, undefined, empty string, or whitespace-only
        if (value === null || value === undefined || value === '' || value.toString().trim() === '') {
          errors.push(`Row ${rowNumber}: ${field} is required but found empty/null value`);
        }
      });

      // Enhanced numeric validation with better error messages
      if (fishData['max_size_(cm)'] !== null && fishData['max_size_(cm)'] !== undefined && fishData['max_size_(cm)'] !== '') {
        const size = parseFloat(fishData['max_size_(cm)']);
        if (isNaN(size)) {
          errors.push(`Row ${rowNumber}: max_size_(cm) must be a number (found: "${fishData['max_size_(cm)']}")`);
        } else if (size <= 0) {
          errors.push(`Row ${rowNumber}: max_size_(cm) must be greater than 0 (found: ${size})`);
        } else if (size > 200) {
          errors.push(`Row ${rowNumber}: max_size_(cm) seems too large (found: ${size}cm) - please verify`);
        }
      }
      
      if (fishData['minimum_tank_size_(l)'] !== null && fishData['minimum_tank_size_(l)'] !== undefined && fishData['minimum_tank_size_(l)'] !== '') {
        const tankSize = parseFloat(fishData['minimum_tank_size_(l)']);
        if (isNaN(tankSize)) {
          errors.push(`Row ${rowNumber}: minimum_tank_size_(l) must be a number (found: "${fishData['minimum_tank_size_(l)']}")`);
        } else if (tankSize <= 0) {
          errors.push(`Row ${rowNumber}: minimum_tank_size_(l) must be greater than 0 (found: ${tankSize})`);
        } else if (tankSize > 10000) {
          errors.push(`Row ${rowNumber}: minimum_tank_size_(l) seems too large (found: ${tankSize}L) - please verify`);
        }
      }
      
      if (fishData['bioload'] !== null && fishData['bioload'] !== undefined && fishData['bioload'] !== '') {
        const bioload = parseFloat(fishData['bioload']);
        if (isNaN(bioload)) {
          errors.push(`Row ${rowNumber}: bioload must be a number (found: "${fishData['bioload']}")`);
        } else if (bioload < 0) {
          errors.push(`Row ${rowNumber}: bioload cannot be negative (found: ${bioload})`);
        } else if (bioload > 10) {
          errors.push(`Row ${rowNumber}: bioload must be between 0-10 (found: ${bioload})`);
        }
      }
      
      if (fishData['portion_grams'] !== null && fishData['portion_grams'] !== undefined && fishData['portion_grams'] !== '') {
        const portion = parseFloat(fishData['portion_grams']);
        if (isNaN(portion)) {
          errors.push(`Row ${rowNumber}: portion_grams must be a number (found: "${fishData['portion_grams']}")`);
        } else if (portion <= 0) {
          errors.push(`Row ${rowNumber}: portion_grams must be greater than 0 (found: ${portion})`);
        } else if (portion > 100) {
          errors.push(`Row ${rowNumber}: portion_grams seems too large (found: ${portion}g) - please verify`);
        }
      }

      // Enhanced enum validation with better error messages
      if (fishData['water_type'] && fishData['water_type'].trim() !== '') {
        const validWaterTypes = ['Freshwater', 'Saltwater'];
        if (!validWaterTypes.includes(fishData['water_type'])) {
          errors.push(`Row ${rowNumber}: water_type must be one of: ${validWaterTypes.join(', ')} (found: "${fishData['water_type']}")`);
        }
      }

      if (fishData['temperament'] && fishData['temperament'].trim() !== '') {
        const validTemperaments = ['Peaceful', 'Semi-aggressive', 'Aggressive'];
        if (!validTemperaments.includes(fishData['temperament'])) {
          errors.push(`Row ${rowNumber}: temperament must be one of: ${validTemperaments.join(', ')} (found: "${fishData['temperament']}")`);
        }
      }

      if (fishData['diet'] && fishData['diet'].trim() !== '') {
        const validDiets = ['Omnivore', 'Herbivore', 'Carnivore'];
        if (!validDiets.includes(fishData['diet'])) {
          errors.push(`Row ${rowNumber}: diet must be one of: ${validDiets.join(', ')} (found: "${fishData['diet']}")`);
        }
      }

      // Check for suspiciously short text fields
      const textFields = ['common_name', 'scientific_name', 'ph_range', 'temperature_range', 'social_behavior', 'lifespan', 'preferred_food', 'feeding_frequency', 'feeding_notes'];
      textFields.forEach(field => {
        if (fishData[field] && fishData[field].toString().trim().length < 2) {
          errors.push(`Row ${rowNumber}: ${field} seems too short (found: "${fishData[field]}") - please verify`);
        }
      });

      if (errors.length === 0) {
        validFish.push(fishData);
      } else {
        validationErrors.push(...errors);
      }
    });

    if (validationErrors.length > 0) {
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: validationErrors 
      });
    }

    // Insert valid fish data
    const results = [];
    let successCount = 0;
    let errorCount = 0;

    for (const fishData of validFish) {
      try {
        const { data, error } = await supabase
          .from('fish_species')
          .insert([{
            common_name: fishData.common_name,
            scientific_name: fishData.scientific_name,
            'max_size_(cm)': parseFloat(fishData['max_size_(cm)']),
            temperament: fishData.temperament,
            water_type: fishData.water_type,
            ph_range: fishData.ph_range,
            social_behavior: fishData.social_behavior,
            tank_level: fishData.tank_level,
            'minimum_tank_size_(l)': parseInt(fishData['minimum_tank_size_(l)']),
            diet: fishData.diet,
            lifespan: fishData.lifespan,
            care_level: fishData.care_level,
            preferred_food: fishData.preferred_food,
            feeding_frequency: fishData.feeding_frequency,
            bioload: parseFloat(fishData.bioload),
            portion_grams: parseFloat(fishData.portion_grams),
            feeding_notes: fishData.feeding_notes,
            description: fishData.description,
            overfeeding_risks: fishData.overfeeding_risks,
            temperature_range: fishData.temperature_range,
            active: true,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
          }])
          .select()
          .single();

        if (error) throw error;
        
        results.push({ 
          common_name: fishData.common_name, 
          success: true, 
          data 
        });
        successCount++;
      } catch (error) {
        console.error(`Error inserting ${fishData.common_name}:`, error);
        results.push({ 
          common_name: fishData.common_name, 
          success: false, 
          error: error.message 
        });
        errorCount++;
      }
    }

    res.json({
      message: 'Bulk upload completed',
      successCount,
      errorCount,
      results
    });
  } catch (error) {
    console.error('Bulk upload error:', error);
    res.status(500).json({ message: 'Failed to perform bulk upload' });
  }
});

// Bulk operations
router.post('/bulk-update', authenticateAdmin, async (req, res) => {
  try {
    const { updates } = req.body;

    if (!Array.isArray(updates) || updates.length === 0) {
      return res.status(400).json({ message: 'Updates array is required' });
    }

    const results = [];
    
    for (const update of updates) {
      try {
        const { data, error } = await supabase
          .from('fish_species')
          .update({
            ...update.data,
            last_updated: new Date().toISOString()
          })
          .eq('id', update.id)
          .select()
          .single();

        if (error) throw error;
        results.push({ id: update.id, success: true, data });
      } catch (error) {
        results.push({ id: update.id, success: false, error: error.message });
      }
    }

    res.json({
      message: 'Bulk update completed',
      results
    });
  } catch (error) {
    console.error('Bulk update error:', error);
    res.status(500).json({ message: 'Failed to perform bulk update' });
  }
});

module.exports = router;
