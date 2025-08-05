const express = require('express');
const router = express.Router();
const { createClient } = require('@supabase/supabase-js');
const { requireAdminRole } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

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
router.get('/', requireAdminRole, async (req, res) => {
  try {
    // Get status from query params, default to 'active'
    const status = req.query.status || 'active';
    
    let query = supabase
      .from('fish_species')
      .select('*')
      .order('common_name');
    
    // Filter by status if provided
    if (status !== 'all') {
      query = query.eq('status', status);
    }
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    console.log(`Found ${data.length} fish with status '${status}'`);
    
    // Log the view action
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'VIEW_FISH_LIST',
      details: `Viewed fish species list (${status})`,
      ip_address: req.ip
    }]);
    
    res.json(data);
  } catch (error) {
    console.error('Error fetching fish:', error);
    res.status(500).json({ error: 'Failed to fetch fish' });
  }
});

// Get a single fish by ID
router.get('/:id', requireAdminRole, async (req, res) => {
  try {
    const { id } = req.params;
    const { data, error } = await supabase
      .from('fish_species')
      .select('*')
      .eq('id', id)
      .single();
    
    if (error) throw error;
    if (!data) {
      return res.status(404).json({ error: 'Fish species not found' });
    }
    
    res.json(data);
  } catch (error) {
    console.error('Error fetching fish species:', error);
    res.status(500).json({ error: 'Server error while fetching fish species' });
  }
});

// Add new fish
router.post('/', requireAdminRole, upload.single('image'), async (req, res) => {
  try {
    const fishData = req.body;
    
    // Add image path if an image was uploaded
    if (req.file) {
      fishData.image_url = `/uploads/fish/${req.file.filename}`;
    }
    
    const { data, error } = await supabase
      .from('fish_species')
      .insert([fishData])
      .select()
      .single();
    
    if (error) throw error;
    
    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_ADDED',
      details: `Added new fish: ${fishData.common_name}`,
      ip_address: req.ip
    }]);
    
    res.status(201).json(data);
  } catch (error) {
    console.error('Error adding fish:', error);
    res.status(500).json({ error: 'Failed to add fish' });
  }
});

// Update fish
router.put('/:id', requireAdminRole, upload.single('image'), async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    // Add image path if an image was uploaded
    if (req.file) {
      updateData.image_url = `/uploads/fish/${req.file.filename}`;
    }
    
    const { data, error } = await supabase
      .from('fish_species')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();
    
    if (error) throw error;
    
    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_UPDATED',
      details: `Updated fish: ${updateData.common_name || id}`,
      ip_address: req.ip
    }]);
    
    res.json(data);
  } catch (error) {
    console.error('Error updating fish:', error);
    res.status(500).json({ error: 'Failed to update fish' });
  }
});

// Delete fish
router.delete('/:id', requireAdminRole, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get fish details before deletion
    const { data: fish, error: fetchError } = await supabase
      .from('fish_species')
      .select('common_name, image_url')
      .eq('id', id)
      .single();
    
    if (fetchError) throw fetchError;
    
    // Delete the fish
    const { error: deleteError } = await supabase
      .from('fish_species')
      .delete()
      .eq('id', id);
    
    if (deleteError) throw deleteError;
    
    // Delete image file if it exists
    if (fish.image_url) {
      const imagePath = path.join(__dirname, '..', fish.image_url);
      if (fs.existsSync(imagePath)) {
        fs.unlinkSync(imagePath);
      }
    }
    
    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_DELETED',
      details: `Deleted fish: ${fish.common_name}`,
      ip_address: req.ip
    }]);
    
    res.json({ message: 'Fish deleted successfully' });
  } catch (error) {
    console.error('Error deleting fish:', error);
    res.status(500).json({ error: 'Failed to delete fish' });
  }
});

module.exports = router;