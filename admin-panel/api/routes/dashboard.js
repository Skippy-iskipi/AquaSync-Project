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

// Get recent user activities across all users
router.get('/recent-activities', async (req, res) => {
  try {
    const { limit = 20 } = req.query;
    
    // Get recent activities from all activity tables
    const activityTypes = [
      'fish_predictions',
      'water_calculations', 
      'fish_calculations',
      'diet_calculations',
      'fish_volume_calculations',
      'compatibility_results',
      'tanks'
    ];

    const allActivities = [];
    
    for (const tableName of activityTypes) {
      try {
        const { data, error } = await supabase
          .from(tableName)
          .select('*')
          .order('created_at', { ascending: false })
          .limit(parseInt(limit));
        
        if (!error && data) {
          data.forEach(item => {
            allActivities.push({
              ...item,
              activity_type: tableName,
              user_id: item.user_id || 'unknown'
            });
          });
        }
      } catch (tableError) {
        console.warn(`Error fetching ${tableName}:`, tableError.message);
        // Continue with other tables even if one fails
      }
    }

    // Sort all activities by created_at (newest first)
    allActivities.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    
    // Add user information to activities by fetching each user individually
    const activitiesWithUsers = await Promise.all(
      allActivities.map(async (activity) => {
        let userEmail = 'Unknown User';
        let userName = 'Unknown User';
        
        if (activity.user_id && activity.user_id !== 'unknown') {
          try {
            // Try to get user from profiles table first
            const { data: profile, error: profileError } = await supabase
              .from('profiles')
              .select('email, full_name, username')
              .eq('id', activity.user_id)
              .single();
            
            if (!profileError && profile) {
              userEmail = profile.email || 'Unknown User';
              userName = profile.full_name || profile.username || 'Unknown User';
            } else {
              // If not found in profiles, try auth.users
              const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(activity.user_id);
              if (!authError && authUser && authUser.user) {
                userEmail = authUser.user.email || 'Unknown User';
                userName = authUser.user.user_metadata?.full_name || 
                          authUser.user.user_metadata?.username || 
                          'Unknown User';
              }
            }
          } catch (error) {
            console.warn(`Error fetching user ${activity.user_id}:`, error.message);
          }
        }
        
        return {
          ...activity,
          user_email: userEmail,
          user_name: userName
        };
      })
    );
    
    // Return top N activities
    res.json(activitiesWithUsers.slice(0, parseInt(limit)));
  } catch (error) {
    console.error('Recent activities error:', error);
    res.status(500).json({ message: 'Failed to fetch recent activities' });
  }
});

// Get user login times and activity summary
router.get('/user-logins', async (req, res) => {
  try {
    const { limit = 50 } = req.query;
    
    // Get all auth users with their sign in data
    const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers();
    
    if (authError) {
      console.error('Error fetching auth users:', authError);
      return res.status(500).json({ message: 'Failed to fetch auth users' });
    }

    if (!authUsers || !authUsers.users) {
      return res.json([]);
    }

    // Filter out admin users
    const regularUsers = authUsers.users.filter(authUser => {
      // Exclude users with admin role or admin email patterns
      const isAdmin = authUser.user_metadata?.role === 'admin' || 
                     authUser.email?.includes('admin') ||
                     authUser.email?.includes('@admin') ||
                     authUser.app_metadata?.role === 'admin';
      return !isAdmin;
    });

    // Get activity counts for each user
    const usersWithActivities = await Promise.all(
      regularUsers.slice(0, parseInt(limit)).map(async (authUser) => {
        let totalActivities = 0;
        
        // Count activities from each table
        for (const tableName of ['fish_predictions', 'water_calculations', 'fish_calculations', 'diet_calculations', 'fish_volume_calculations', 'compatibility_results', 'tanks']) {
          try {
            const { count } = await supabase
              .from(tableName)
              .select('*', { count: 'exact', head: true })
              .eq('user_id', authUser.id);
            totalActivities += count || 0;
          } catch (tableError) {
            // Table might not exist, continue
          }
        }

        // Try to get additional profile data
        let profileData = {};
        try {
          const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('full_name, username, active')
            .eq('id', authUser.id)
            .single();
          
          if (!profileError && profile) {
            profileData = profile;
          }
        } catch (profileError) {
          // Profile might not exist, continue with auth data only
        }
        
        return {
          id: authUser.id,
          email: authUser.email,
          full_name: profileData.full_name || authUser.user_metadata?.full_name || null,
          username: profileData.username || authUser.user_metadata?.username || null,
          active: profileData.active !== undefined ? profileData.active : !authUser.banned_until,
          created_at: authUser.created_at,
          last_sign_in_at: authUser.last_sign_in_at,
          email_confirmed_at: authUser.email_confirmed_at,
          total_activities: totalActivities
        };
      })
    );

    // Sort by last sign in time (most recent first)
    usersWithActivities.sort((a, b) => {
      if (!a.last_sign_in_at && !b.last_sign_in_at) return 0;
      if (!a.last_sign_in_at) return 1;
      if (!b.last_sign_in_at) return -1;
      return new Date(b.last_sign_in_at) - new Date(a.last_sign_in_at);
    });

    res.json(usersWithActivities);
  } catch (error) {
    console.error('User logins error:', error);
    res.status(500).json({ message: 'Failed to fetch user login data' });
  }
});

module.exports = router;
