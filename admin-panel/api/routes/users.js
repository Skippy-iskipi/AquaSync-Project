const express = require('express');
const { body, validationResult } = require('express-validator');
const supabase = require('../config/supabase');
const { authenticateAdmin } = require('../middleware/auth');

const router = express.Router();

// Get all users with pagination and filtering (temporary - no auth for development)
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 50, search = '', status = 'all' } = req.query;
    const offset = (page - 1) * limit;

    // First get users from auth.users (Supabase Auth)
    const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers({
      page: parseInt(page),
      perPage: parseInt(limit)
    });

    if (authError) throw authError;

    // Then get profile data for each user
    const userIds = authUsers.users.map(user => user.id);
    
    let profileQuery = supabase
      .from('profiles')
      .select(`
        id,
        email,
        role,
        active,
        updated_at
      `)
      .in('id', userIds);

    const { data: profiles, error: profileError } = await profileQuery;
    
    if (profileError && profileError.code !== 'PGRST116') { // PGRST116 = no rows returned
      throw profileError;
    }

    // Merge auth data with profile data
    const mergedUsers = authUsers.users.map(authUser => {
        const profile = profiles?.find(p => p.id === authUser.id) || {};
        
        return {
          id: authUser.id,
          email: authUser.email,
          email_confirmed_at: authUser.email_confirmed_at,
          created_at: authUser.created_at,
          last_sign_in_at: authUser.last_sign_in_at,
          active: profile.active !== undefined ? profile.active : !authUser.banned_until, // Use profile.active if available, fallback to auth
          role: profile.role || 'user',
          username: profile.username || null,
          full_name: profile.full_name || null,
          avatar_url: profile.avatar_url || null,
          phone: profile.phone || null,
          bio: profile.bio || null,
          updated_at: profile.updated_at || null
        };
      });

    // Apply search filter
    let filteredUsers = mergedUsers;
    if (search) {
      const searchLower = search.toLowerCase();
      filteredUsers = mergedUsers.filter(user => 
        user.email?.toLowerCase().includes(searchLower) ||
        user.username?.toLowerCase().includes(searchLower) ||
        user.full_name?.toLowerCase().includes(searchLower)
      );
    }

    // Apply status filter
    if (status !== 'all') {
      filteredUsers = filteredUsers.filter(user => {
        if (status === 'active') return user.active;
        if (status === 'inactive') return !user.active;
        return true;
      });
    }

    res.json(filteredUsers);
  } catch (error) {
    console.error('Users fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch users' });
  }
});

// Create new user
router.post('/', [
  authenticateAdmin,
  body('email').isEmail().withMessage('Valid email is required'),
  body('active').optional().isBoolean().withMessage('Active must be a boolean')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    const { email, active = true } = req.body;

    console.log('Creating user with email:', email, 'active:', active);

    // Check if user already exists
    const { data: existingUser, error: checkError } = await supabase.auth.admin.listUsers();
    if (checkError) {
      console.error('Error checking existing users:', checkError);
      return res.status(500).json({ message: 'Failed to check existing users' });
    }

    const userExists = existingUser.users.some(user => user.email === email);
    if (userExists) {
      console.log('User already exists with email:', email);
      return res.status(409).json({ message: 'User with this email already exists' });
    }

    // Generate a temporary password (user will need to reset it)
    const tempPassword = Math.random().toString(36).slice(-12) + 'A1!';
    console.log('Generated temp password for user');

    // Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email,
      password: tempPassword,
      email_confirm: true, // Auto-confirm email
      user_metadata: {
        created_by_admin: true
      }
    });

    if (authError) {
      console.error('Auth creation error:', authError);
      if (authError.message && authError.message.includes('already registered')) {
        return res.status(409).json({ message: 'User with this email already exists' });
      }
      return res.status(400).json({ 
        message: 'Failed to create user in authentication system', 
        error: authError.message || 'Unknown auth error' 
      });
    }

    console.log('Auth user created successfully:', authData.user.id);

    // Create or update profile entry (use upsert to handle existing profiles)
    // Note: We need to use the service role client for this operation
    const profileDataToInsert = {
      id: authData.user.id,
      email: email,
      tier_plan: 'free',
      updated_at: new Date().toISOString()
    };
    
    console.log('Attempting to create profile with data:', profileDataToInsert);
    
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .upsert([profileDataToInsert], {
        onConflict: 'id'
      })
      .select()
      .single();

    if (profileError) {
      console.error('Profile creation error:', profileError);
      // If profile creation fails, we should clean up the auth user
      try {
        await supabase.auth.admin.deleteUser(authData.user.id);
        console.log('Cleaned up auth user after profile creation failure');
      } catch (cleanupError) {
        console.error('Failed to cleanup auth user:', cleanupError);
      }
      return res.status(400).json({ 
        message: 'Failed to create user profile', 
        error: profileError.message || 'Unknown profile error' 
      });
    }

    console.log('Profile created successfully:', profileData);

    // Set user active status if needed
    if (!active) {
      try {
        await supabase.auth.admin.updateUserById(authData.user.id, {
          ban_duration: '876000h' // Ban for 100 years (effectively permanent)
        });
        console.log('User set to inactive');
      } catch (banError) {
        console.error('Failed to ban user:', banError);
        // Don't fail the entire operation for this
      }
    }

    res.status(201).json({
      message: 'User created successfully',
      data: {
        id: authData.user.id,
        email: authData.user.email,
        active: active,
        created_at: authData.user.created_at,
        email_confirmed_at: authData.user.email_confirmed_at
      }
    });

  } catch (error) {
    console.error('User creation error:', error);
    res.status(500).json({ 
      message: 'Failed to create user', 
      error: error.message || 'Unknown error' 
    });
  }
});

// Get single user by ID
router.get('/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    // Get user from auth
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(id);
    if (authError) throw authError;

    // Get profile data
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', id)
      .single();

    // Merge data (profile might not exist)
    const userData = {
      id: authUser.user.id,
      email: authUser.user.email,
      email_confirmed_at: authUser.user.email_confirmed_at,
      created_at: authUser.user.created_at,
      last_sign_in_at: authUser.user.last_sign_in_at,
      active: !authUser.user.banned_until,
      username: profile?.username || null,
      full_name: profile?.full_name || null,
      avatar_url: profile?.avatar_url || null,
      phone: profile?.phone || null,
      bio: profile?.bio || null,
      updated_at: profile?.updated_at || null
    };

    res.json(userData);
  } catch (error) {
    console.error('User fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch user' });
  }
});

// Update user profile
router.put('/:id', [
  authenticateAdmin,
  body('email').optional().isEmail().withMessage('Invalid email format'),
  body('username').optional().isLength({ min: 3, max: 30 }).withMessage('Username must be 3-30 characters'),
  body('full_name').optional().isLength({ max: 100 }).withMessage('Full name too long'),
  body('phone').optional().isMobilePhone().withMessage('Invalid phone number')
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
    const { email, username, full_name, avatar_url, phone, bio } = req.body;

    // Update email in auth if provided
    if (email) {
      const { error: authError } = await supabase.auth.admin.updateUserById(id, {
        email: email
      });
      if (authError) throw authError;
    }

    // Update profile data
    const profileData = {
      username,
      full_name,
      avatar_url,
      phone,
      bio,
      updated_at: new Date().toISOString()
    };

    // Remove undefined values
    Object.keys(profileData).forEach(key => {
      if (profileData[key] === undefined) {
        delete profileData[key];
      }
    });

    const { data, error } = await supabase
      .from('profiles')
      .upsert({ id, ...profileData })
      .select()
      .single();

    if (error) throw error;

    res.json({
      message: 'User updated successfully',
      data
    });
  } catch (error) {
    console.error('User update error:', error);
    if (error.code === '23505') {
      res.status(409).json({ message: 'Username or email already exists' });
    } else {
      res.status(500).json({ message: 'Failed to update user' });
    }
  }
});

// Test endpoint to check if user status update is working
router.get('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    console.log('Getting user status for ID:', id);
    
    // Check profiles table first
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, active, updated_at')
      .eq('id', id)
      .single();
    
    if (profileError) {
      console.error('Profile error:', profileError);
    }
    
    // Also check auth user
    const { data: user, error: authError } = await supabase.auth.admin.getUserById(id);
    if (authError) {
      console.error('Auth error:', authError);
    }
    
    const authActive = user ? !user.user.banned_until : null;
    const profileActive = profile ? profile.active : null;
    
    console.log('User status comparison:', { 
      id, 
      profileActive, 
      authActive, 
      profile: profile ? 'Found' : 'Not found',
      auth: user ? 'Found' : 'Not found'
    });
    
    res.json({
      id: id,
      email: profile?.email || user?.user?.email,
      profileActive: profileActive,
      authActive: authActive,
      profileData: profile,
      authData: user ? {
        banned_until: user.user.banned_until,
        email: user.user.email
      } : null
    });
  } catch (error) {
    console.error('Get user status error:', error);
    res.status(500).json({ message: 'Failed to get user status', error: error.message });
  }
});

// Test endpoint to check if active column exists
router.get('/test/active-column', async (req, res) => {
  try {
    console.log('Testing if active column exists in profiles table');
    
    // Try to select the active column from profiles table
    const { data, error } = await supabase
      .from('profiles')
      .select('id, email, active')
      .limit(1);
    
    if (error) {
      console.error('Error checking active column:', error);
      res.json({
        success: false,
        error: error.message,
        code: error.code,
        details: error.details
      });
    } else {
      console.log('Active column test successful:', data);
      res.json({
        success: true,
        message: 'Active column exists',
        sampleData: data
      });
    }
  } catch (error) {
    console.error('Test active column error:', error);
    res.status(500).json({ message: 'Failed to test active column', error: error.message });
  }
});

// Test endpoint to check current user's active status (for Flutter app testing)
router.get('/test/current-user-status', async (req, res) => {
  try {
    console.log('Testing current user status check');
    
    // Get all users to test with
    const { data: users, error: usersError } = await supabase
      .from('profiles')
      .select('id, email, active, created_at')
      .limit(5);
    
    if (usersError) {
      console.error('Error getting users:', usersError);
      res.json({
        success: false,
        error: usersError.message
      });
    } else {
      console.log('Current users and their active status:', users);
      res.json({
        success: true,
        message: 'Current users and their active status',
        users: users
      });
    }
  } catch (error) {
    console.error('Test current user status error:', error);
    res.status(500).json({ message: 'Failed to test current user status', error: error.message });
  }
});

// Toggle user active status (ban/unban) - Temporarily without auth for testing
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { active } = req.body;

    console.log('Status update request:', { id, active, type: typeof active });

    if (typeof active !== 'boolean') {
      console.log('Invalid active type:', typeof active);
      return res.status(400).json({ message: 'Active status must be a boolean' });
    }

    // Update the profiles table with the active status
    const profileUpdateData = {
      active: active,
      updated_at: new Date().toISOString()
    };

    console.log('Updating profiles table with data:', profileUpdateData);

    const { data: profileResult, error: profileError } = await supabase
      .from('profiles')
      .update(profileUpdateData)
      .eq('id', id)
      .select()
      .single();
    
    if (profileError) {
      console.error('Profiles table update error:', profileError);
      throw profileError;
    }

    console.log('Profiles table updated successfully:', profileResult);
    
    // Also update the auth user for consistency
    const authUpdateData = active 
      ? { banned_until: null } 
      : { banned_until: new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000).toISOString() };

    const { error: authError } = await supabase.auth.admin.updateUserById(id, authUpdateData);
    
    if (authError) {
      console.error('Auth update error (non-critical):', authError);
      // Don't fail the entire operation for this
    } else {
      console.log('Auth user updated successfully');
    }
    
    // Verify the update by fetching the profile again
    const { data: verifyProfile, error: verifyError } = await supabase
      .from('profiles')
      .select('id, email, active, updated_at')
      .eq('id', id)
      .single();
      
    if (verifyError) {
      console.error('Error verifying profile update:', verifyError);
    } else {
      console.log('Profile after update:', verifyProfile);
    }

    res.json({
      message: `User ${active ? 'activated' : 'deactivated'} successfully`
    });
  } catch (error) {
    console.error('User status update error:', error);
    res.status(500).json({ 
      message: 'Failed to update user status',
      error: error.message || 'Unknown error'
    });
  }
});

// Delete user (soft delete by banning permanently)
router.delete('/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    console.log('Attempting to delete user with ID:', id);

    // Hard delete the user from Supabase Auth
    // This completely removes the user from the authentication system
    console.log('Deleting user from Supabase Auth...');
    
    const { error: authError } = await supabase.auth.admin.deleteUser(id);
    
    console.log('Auth deletion error:', authError);

    if (authError) {
      console.error('Auth deletion error:', authError);
      throw authError;
    }

    console.log('User deleted successfully from auth');

    // Optionally, you could also soft delete the profile
    // Note: profiles table doesn't have deleted_at, username, or email columns
    // So we'll just update the updated_at timestamp
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ 
        updated_at: new Date().toISOString()
      })
      .eq('id', id);

    if (profileError) {
      console.error('Profile update error (non-critical):', profileError);
      // Don't throw on profile error as profile might not exist
    } else {
      console.log('Profile updated successfully');
    }

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('User deletion error:', error);
    res.status(500).json({ 
      message: 'Failed to delete user',
      error: error.message || 'Unknown error'
    });
  }
});

// Get user's tanks with comprehensive data
router.get('/:id/tanks', async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from('tanks')
      .select(`
        created_at,
        name,
        tank_shape,
        length,
        width,
        height,
        unit,
        volume,
        fish_selections,
        compatibility_results,
        feeding_recommendations,
        available_feeds,
        feed_inventory,
        date_created,
        last_updated,
        feed_portion_data,
        recommended_fish_quantities
      `)
      .eq('user_id', id)
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json(data || []);
  } catch (error) {
    console.error('User tanks fetch error:', error);
    res.status(500).json({ message: 'Failed to fetch user tanks' });
  }
});

// Get user statistics
router.get('/:id/stats', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    // Get tank count
    const { count: tankCount } = await supabase
      .from('tanks')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', id);

    // Get total fish count across all tanks
    const { data: tankFish, error: fishError } = await supabase
      .from('tank_fish')
      .select('quantity, tanks!inner(user_id)')
      .eq('tanks.user_id', id);

    if (fishError) throw fishError;

    const totalFish = tankFish?.reduce((sum, fish) => sum + fish.quantity, 0) || 0;

    // Get account age
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(id);
    if (authError) throw authError;

    const accountAge = Math.floor((new Date() - new Date(authUser.user.created_at)) / (1000 * 60 * 60 * 24));

    res.json({
      tankCount: tankCount || 0,
      totalFish,
      accountAgeDays: accountAge,
      lastSignIn: authUser.user.last_sign_in_at
    });
  } catch (error) {
    console.error('User stats error:', error);
    res.status(500).json({ message: 'Failed to fetch user statistics' });
  }
});

// Get user activities for a specific table
router.get('/:userId/activities/:tableName', async (req, res) => {
  try {
    const { userId, tableName } = req.params;
    const { limit = 50 } = req.query;

    console.log(`Fetching ${tableName} activities for user ${userId}`);

    // Validate table name to prevent SQL injection
    const allowedTables = [
      'fish_predictions',
      'water_calculations',
      'fish_calculations',
      'diet_calculations',
      'fish_volume_calculations',
      'compatibility_results',
      'tanks'
    ];

    if (!allowedTables.includes(tableName)) {
      return res.status(400).json({ message: 'Invalid table name' });
    }

    // Build the query based on table name
    let query = supabase
      .from(tableName)
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(parseInt(limit));

    const { data, error } = await query;

    if (error) {
      console.error(`Error fetching ${tableName}:`, error);
      // If table doesn't exist, return empty array instead of error
      if (error.message && error.message.includes('relation') && error.message.includes('does not exist')) {
        return res.json([]);
      }
      throw error;
    }

    console.log(`Found ${data?.length || 0} ${tableName} records for user ${userId}`);
    res.json(data || []);
  } catch (error) {
    console.error(`Error fetching user activities for ${req.params.tableName}:`, error);
    res.status(500).json({ 
      message: `Failed to fetch ${req.params.tableName} activities`,
      error: error.message 
    });
  }
});

module.exports = router;
