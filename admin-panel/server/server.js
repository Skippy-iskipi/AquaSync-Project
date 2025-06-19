const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Import routes
const datasetsRouter = require('./routes/datasets');
const modelsRouter = require('./routes/models');
const fishRouter = require('./routes/fish');

// Initialize express app
const app = express();
const PORT = process.env.PORT || 8080;

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Middleware
app.use(cors());
app.use(express.json());

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) return res.status(401).json({ message: 'Access denied. No token provided.' });
  
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error) throw error;
    
    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({ message: 'Invalid or expired token.' });
  }
};

// Use routers
app.use('/api/admin/datasets', datasetsRouter);
app.use('/api/admin/model', modelsRouter);
app.use('/api/admin/fish', fishRouter);

// Fish management routes
app.get('/api/admin/fish', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('fish_species')
      .select('*')
      .order('common_name');
      
    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('Error fetching fish list:', error);
    res.status(500).json({ error: 'Failed to fetch fish list' });
  }
});

app.post('/api/admin/fish', authenticateToken, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('fish_species')
      .insert([req.body])
      .select()
      .single();

    if (error) throw error;

    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_ADDED',
      details: `Added new fish: ${req.body.common_name} (${req.body.scientific_name})`,
      ip_address: req.ip
    }]);
    
    res.status(201).json(data);
  } catch (error) {
    console.error('Error adding fish:', error);
    res.status(500).json({ error: 'Failed to add fish' });
  }
});

app.put('/api/admin/fish/:id', authenticateToken, async (req, res) => {
  try {
    const id = req.params.id;
    
    // Get original fish data
    const { data: oldFish, error: fetchError } = await supabase
      .from('fish_species')
      .select('*')
      .eq('id', id)
      .single();
      
    if (fetchError) throw fetchError;
    if (!oldFish) return res.status(404).json({ error: 'Fish not found' });

    // Update fish
    const { data, error } = await supabase
      .from('fish_species')
      .update(req.body)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    // Generate change log
    const changes = [];
    Object.keys(req.body).forEach(key => {
      if (oldFish[key] !== req.body[key]) {
        changes.push(`${key} from "${oldFish[key] || 'not set'}" to "${req.body[key]}"`);
      }
    });

    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_UPDATED',
      details: changes.length > 0 
        ? `Updated ${req.body.common_name}: Changed ${changes.join('; ')}`
        : `Updated ${req.body.common_name} with no changes detected`,
      ip_address: req.ip
    }]);
    
    res.json(data);
  } catch (error) {
    console.error('Error updating fish:', error);
    res.status(500).json({ error: 'Failed to update fish' });
  }
});

app.delete('/api/admin/fish/:id', authenticateToken, async (req, res) => {
  try {
    const id = req.params.id;
    
    // Get fish details before deletion
    const { data: fishDetails, error: fetchError } = await supabase
      .from('fish_species')
      .select('common_name, scientific_name')
      .eq('id', id)
      .single();
      
    if (fetchError) throw fetchError;
    if (!fishDetails) return res.status(404).json({ error: 'Fish not found' });

    // Delete fish
    const { error } = await supabase
      .from('fish_species')
      .delete()
      .eq('id', id);

    if (error) throw error;

    // Log activity
    await supabase.from('admin_activity').insert([{
      user_id: req.user.id,
      action_type: 'FISH_DELETED',
      details: `Deleted fish: ${fishDetails.common_name} (${fishDetails.scientific_name})`,
      ip_address: req.ip
    }]);
    
    res.json({ message: 'Fish deleted successfully' });
  } catch (error) {
    console.error('Error deleting fish:', error);
    res.status(500).json({ error: 'Failed to delete fish' });
  }
});

// Dashboard data endpoint
app.get('/api/admin/dashboard', authenticateToken, async (req, res) => {
  try {
    // Get fish count
    const { count, error: countError } = await supabase
      .from('fish_species')
      .select('*', { count: 'exact', head: true });
      
    if (countError) throw countError;
    
    // Get water type distribution
    const { data: waterTypeData, error: waterTypeError } = await supabase
      .from('fish_species')
      .select('water_type, count')
      .group('water_type');
      
    if (waterTypeError) throw waterTypeError;
    
    // Get temperament distribution
    const { data: temperamentData, error: temperamentError } = await supabase
      .from('fish_species')
      .select('temperament, count')
      .group('temperament');
      
    if (temperamentError) throw temperamentError;

    // Get recent activities
    const { data: activities, error: activitiesError } = await supabase
      .from('admin_activity')
      .select(`
        id,
        action_type,
        details,
        created_at,
        ip_address,
        admin_users (username)
      `)
      .not('action_type', 'in', '("USER_LOGIN","LOGIN_FAILED","VIEW_FISH_LIST")')
      .order('created_at', { ascending: false })
      .limit(10);
      
    if (activitiesError) throw activitiesError;
    
    res.json({
      statistics: {
        totalFish: count,
        waterTypeStats: waterTypeData,
        temperamentStats: temperamentData
      },
      recentActivity: activities.map(activity => ({
        id: activity.id,
        type: activity.action_type,
        details: activity.details,
        date: new Date(activity.created_at).toLocaleString(),
        username: activity.admin_users?.username
      }))
    });
    
  } catch (error) {
    console.error('Dashboard data error:', error);
    res.status(500).json({ 
      message: 'Internal server error',
      statistics: {
        totalFish: 0,
        waterTypeStats: [],
        temperamentStats: []
      },
      recentActivity: []
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
}); 