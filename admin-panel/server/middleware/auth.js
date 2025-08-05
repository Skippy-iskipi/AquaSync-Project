const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET || 'aquasync-admin-secret';

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Middleware to authenticate admin users
const authenticateAdmin = async (req, res, next) => {
  console.log('Authenticating admin request...');
  try {
    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      console.log('No token provided');
      return res.status(401).json({ error: 'Authentication required' });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    console.log('Token decoded:', { userId: decoded.userId });
    
    // Check if user exists in admin_users table
    const { data: adminUser, error } = await supabase
      .from('admin_users')
      .select('id, username, role')
      .eq('id', decoded.userId)
      .single();
    
    if (error) {
      console.error('Supabase error:', error);
      return res.status(401).json({ error: 'Invalid authentication - Admin access required' });
    }

    if (!adminUser) {
      console.log('No admin user found for id:', decoded.userId);
      return res.status(401).json({ error: 'Invalid authentication - Admin access required' });
    }

    console.log('Admin user authenticated:', { username: adminUser.username, role: adminUser.role });
    
    // Add user to request
    req.user = adminUser;
    next();
  } catch (error) {
    console.error('Auth error:', error);
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    res.status(500).json({ error: 'Server error during authentication' });
  }
};

// Enhanced admin-only middleware that verifies admin role
const requireAdminRole = async (req, res, next) => {
  console.log('Verifying admin role...');
  try {
    // First authenticate the user
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      console.log('No token provided');
      return res.status(401).json({ error: 'Authentication required' });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    console.log('Token decoded:', { userId: decoded.userId });
    
    // Check if user exists in admin_users table and has admin role
    const { data: adminUser, error } = await supabase
      .from('admin_users')
      .select('id, username, role')
      .eq('id', decoded.userId)
      .eq('role', 'admin')
      .single();
    
    if (error) {
      console.error('Supabase error:', error);
      return res.status(403).json({ error: 'Admin role required for this operation' });
    }

    if (!adminUser) {
      console.log('No admin user found or user lacks admin role:', decoded.userId);
      return res.status(403).json({ error: 'Admin role required for this operation' });
    }

    console.log('Admin role verified:', { username: adminUser.username, role: adminUser.role });
    
    // Add user to request
    req.user = adminUser;
    next();
  } catch (error) {
    console.error('Admin auth error:', error);
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    res.status(500).json({ error: 'Server error during authentication' });
  }
};

// Logger middleware for admin activity
const logActivity = async (req, res, next) => {
  // Store the original end function
  const originalEnd = res.end;
  
  // Override the end function
  res.end = async function(chunk, encoding) {
    if (req.user) {
      try {
        // Log the activity using the correct column name
        await supabase.from('admin_activity').insert({
          user_id: req.user.id,
          action_type: req.method + ' ' + req.originalUrl,
          details: JSON.stringify({
            body: req.body,
            params: req.params,
            query: req.query,
            statusCode: res.statusCode
          }),
          ip_address: req.ip
        });
      } catch (error) {
        console.error('Error logging activity:', error);
      }
    }
    
    // Call the original end function
    originalEnd.call(this, chunk, encoding);
  };
  
  next();
};

// Generate JWT token
const generateToken = (userId) => {
  console.log('Generating token for user:', userId);
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '8h' });
};

module.exports = {
  authenticateAdmin,
  requireAdminRole,
  logActivity,
  generateToken
};