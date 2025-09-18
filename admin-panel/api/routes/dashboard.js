const express = require('express');
const supabase = require('../config/supabase');
const { authenticateAdmin } = require('../middleware/auth');

const router = express.Router();

// Get dashboard statistics (temporary - no auth for development)
router.get('/stats', async (req, res) => {
  try {
    // Get total users count
    const { count: totalUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true });

    // Get total fish species count
    const { count: totalFish } = await supabase
      .from('fish_species')
      .select('*', { count: 'exact', head: true });

    // Get total tanks count
    const { count: totalTanks } = await supabase
      .from('tanks')
      .select('*', { count: 'exact', head: true });

    // Get active users (users who signed in within last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const { count: activeUsers } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('updated_at', thirtyDaysAgo.toISOString());

    // Get freshwater fish count
    const { count: freshwaterFish } = await supabase
      .from('fish_species')
      .select('*', { count: 'exact', head: true })
      .eq('water_type', 'Freshwater');

    // Get saltwater fish count
    const { count: saltwaterFish } = await supabase
      .from('fish_species')
      .select('*', { count: 'exact', head: true })
      .eq('water_type', 'Saltwater');

    res.json({
      totalUsers: totalUsers || 0,
      totalFish: totalFish || 0,
      totalTanks: totalTanks || 0,
      activeUsers: activeUsers || 0,
      freshwaterFish: freshwaterFish || 0,
      saltwaterFish: saltwaterFish || 0
    });
  } catch (error) {
    console.error('Dashboard stats error:', error);
    res.status(500).json({ message: 'Failed to fetch dashboard statistics' });
  }
});

// Get user growth data for the last 30 days (temporary - no auth for development)
router.get('/user-growth', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('updated_at')
      .gte('updated_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
      .order('updated_at', { ascending: true });

    if (error) throw error;

    // Group by date and count users
    const growthData = {};
    data.forEach(user => {
      const date = new Date(user.updated_at).toISOString().split('T')[0];
      growthData[date] = (growthData[date] || 0) + 1;
    });

    // Convert to array format for charts
    const chartData = Object.entries(growthData).map(([date, users]) => ({
      date: new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      users
    }));

    res.json(chartData);
  } catch (error) {
    console.error('User growth error:', error);
    res.status(500).json({ message: 'Failed to fetch user growth data' });
  }
});

// Get fish distribution data (temporary - no auth for development)
router.get('/fish-distribution', async (req, res) => {
  try {
    // Get most popular fish species from tanks table (since tank_fish doesn't exist)
    const { data, error } = await supabase
      .from('tanks')
      .select(`
        fish_species,
        fish_quantity
      `);

    if (error) throw error;

    // Aggregate fish counts
    const fishCounts = {};
    data.forEach(item => {
      if (item.fish_species && item.fish_quantity) {
        fishCounts[item.fish_species] = (fishCounts[item.fish_species] || 0) + item.fish_quantity;
      }
    });

    // Convert to chart format and get top 10
    const chartData = Object.entries(fishCounts)
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    res.json(chartData);
  } catch (error) {
    console.error('Fish distribution error:', error);
    res.status(500).json({ message: 'Failed to fetch fish distribution data' });
  }
});

// Get system health data (temporary - no auth for development)
router.get('/system-health', async (req, res) => {
  try {
    const healthChecks = [];

    // Check Supabase connection
    const start1 = Date.now();
    try {
      await supabase.from('profiles').select('id').limit(1);
      healthChecks.push({
        service: 'Supabase Database',
        status: 'healthy',
        responseTime: Date.now() - start1
      });
    } catch (error) {
      healthChecks.push({
        service: 'Supabase Database',
        status: 'error',
        responseTime: Date.now() - start1
      });
    }

    // Check Fish Species API
    const start2 = Date.now();
    try {
      await supabase.from('fish_species').select('id').limit(1);
      healthChecks.push({
        service: 'Fish Species API',
        status: 'healthy',
        responseTime: Date.now() - start2
      });
    } catch (error) {
      healthChecks.push({
        service: 'Fish Species API',
        status: 'error',
        responseTime: Date.now() - start2
      });
    }

    // Check Authentication
    const start3 = Date.now();
    try {
      await supabase.from('admin_users').select('id').limit(1);
      healthChecks.push({
        service: 'Authentication',
        status: 'healthy',
        responseTime: Date.now() - start3
      });
    } catch (error) {
      healthChecks.push({
        service: 'Authentication',
        status: 'warning',
        responseTime: Date.now() - start3
      });
    }

    // Add API Server health
    healthChecks.push({
      service: 'API Server',
      status: 'healthy',
      responseTime: Math.floor(Math.random() * 50) + 10 // Simulated response time
    });

    res.json(healthChecks);
  } catch (error) {
    console.error('System health error:', error);
    res.status(500).json({ message: 'Failed to fetch system health data' });
  }
});

module.exports = router;
