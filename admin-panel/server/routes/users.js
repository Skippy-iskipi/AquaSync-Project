const express = require('express');
const router = express.Router();
const { createClient } = require('@supabase/supabase-js');
const { requireAdminRole, logActivity } = require('../middleware/auth');
require('dotenv').config();

// Initialize Supabase client with timeout
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
  {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false
    },
    global: {
      headers: { 'x-application-name': 'aquasync-admin' },
    },
  }
);

// Error handler wrapper
const asyncHandler = (fn) => (req, res, next) => {
  return Promise.resolve(fn(req, res, next)).catch((error) => {
    console.error('Route Error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message,
      code: error.code
    });
  });
};

// Get all users with their profile information
router.get('/', requireAdminRole, asyncHandler(async (req, res) => {
  console.log('GET /users - Starting request');
  
  const { data: users, error } = await supabase
    .from('profiles')
    .select(`
      id,
      username,
      full_name,
      avatar_url,
      updated_at,
      user:auth.users (
        id,
        email,
        created_at,
        last_sign_in_at,
        confirmed_at
      )
    `)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Supabase error fetching users:', error);
    return res.status(500).json({
      error: 'Database Error',
      message: error.message,
      code: error.code
    });
  }

  console.log(`Successfully fetched ${users?.length || 0} users`);
  res.json(users || []);
}));

// Get a single user by ID
router.get('/:id', requireAdminRole, asyncHandler(async (req, res) => {
  const { id } = req.params;
  console.log(`GET /users/${id} - Starting request`);

  const { data: user, error } = await supabase
    .from('profiles')
    .select(`
      *,
      user:auth.users (
        id,
        email,
        created_at,
        last_sign_in_at,
        confirmed_at
      )
    `)
    .eq('id', id)
    .single();

  if (error) {
    return res.status(500).json({
      error: 'Database Error',
      message: error.message,
      code: error.code
    });
  }

  if (!user) {
    return res.status(404).json({
      error: 'Not Found',
      message: 'User not found'
    });
  }

  res.json(user);
}));

// Create a new user
router.post('/', requireAdminRole, asyncHandler(async (req, res) => {
  const { email, password, ...profileData } = req.body;

  // Create user in auth.users
  const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });

  if (authError) {
    return res.status(400).json({
      error: 'Auth Error',
      message: authError.message,
      code: authError.code
    });
  }

  // Create profile
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .insert([{
      id: authUser.user.id,
      ...profileData
    }])
    .select()
    .single();

  if (profileError) {
    return res.status(500).json({
      error: 'Database Error',
      message: profileError.message,
      code: profileError.code
    });
  }

  // Log activity
  await supabase.from('admin_activity').insert([{
    user_id: req.user.id,
    action_type: 'USER_CREATED',
    details: `Created new user: ${email}`,
    ip_address: req.ip
  }]);

  res.status(201).json(profile);
}));

// Update a user
router.put('/:id', requireAdminRole, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { email, password, ...profileData } = req.body;

  // Update auth user if email or password provided
  if (email || password) {
    const { error: authError } = await supabase.auth.admin.updateUserById(
      id,
      { email, password }
    );

    if (authError) {
      return res.status(400).json({
        error: 'Auth Error',
        message: authError.message,
        code: authError.code
      });
    }
  }

  // Update profile
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .update(profileData)
    .eq('id', id)
    .select()
    .single();

  if (profileError) {
    return res.status(500).json({
      error: 'Database Error',
      message: profileError.message,
      code: profileError.code
    });
  }

  // Log activity
  await supabase.from('admin_activity').insert([{
    user_id: req.user.id,
    action_type: 'USER_UPDATED',
    details: `Updated user: ${id}`,
    ip_address: req.ip
  }]);

  res.json(profile);
}));

// Delete a user
router.delete('/:id', requireAdminRole, asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Get user details before deletion
  const { data: user, error: fetchError } = await supabase
    .from('profiles')
    .select('email')
    .eq('id', id)
    .single();

  if (fetchError) {
    return res.status(500).json({
      error: 'Database Error',
      message: fetchError.message,
      code: fetchError.code
    });
  }

  // Delete user
  const { error: deleteError } = await supabase.auth.admin.deleteUser(id);

  if (deleteError) {
    return res.status(500).json({
      error: 'Auth Error',
      message: deleteError.message,
      code: deleteError.code
    });
  }

  // Log activity
  await supabase.from('admin_activity').insert([{
    user_id: req.user.id,
    action_type: 'USER_DELETED',
    details: `Deleted user: ${user.email}`,
    ip_address: req.ip
  }]);

  res.json({
    message: 'User deleted successfully',
    id
  });
}));

module.exports = router;