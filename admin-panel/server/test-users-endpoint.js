// Test Users API Endpoint
// This script tests the admin users API without authentication

const express = require('express');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = 8081; // Different port to avoid conflicts

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Middleware
app.use(express.json());

// Test endpoint without authentication
app.get('/test/users', async (req, res) => {
  try {
    console.log('Testing users endpoint...');
    
    // Test 1: Check if we can connect to Supabase
    console.log('Testing Supabase connection...');
    const { data: testData, error: testError } = await supabase
      .from('profiles')
      .select('count')
      .limit(1);
    
    if (testError) {
      console.error('Supabase connection error:', testError);
      return res.status(500).json({ error: 'Supabase connection failed', details: testError });
    }
    
    console.log('Supabase connection successful');
    
    // Test 2: Try to fetch users
    console.log('Fetching users...');
    const { data: users, error } = await supabase
      .from('profiles')
      .select(`
        id,
        email,
        tier_plan,
        compatibility_checks_count,
        updated_at,
        role
      `)
      .limit(5);
    
    if (error) {
      console.error('Error fetching users:', error);
      return res.status(500).json({ error: 'Failed to fetch users', details: error });
    }
    
    console.log('Users fetched successfully:', users?.length || 0, 'users');
    
    // Test 3: Check admin tables
    console.log('Checking admin tables...');
    const { data: adminUsers, error: adminError } = await supabase
      .from('admin_users')
      .select('*')
      .limit(5);
    
    if (adminError) {
      console.error('Error fetching admin users:', adminError);
    } else {
      console.log('Admin users found:', adminUsers?.length || 0);
    }
    
    res.json({
      success: true,
      message: 'Test completed successfully',
      data: {
        users: users || [],
        adminUsers: adminUsers || [],
        userCount: users?.length || 0,
        adminUserCount: adminUsers?.length || 0
      }
    });
    
  } catch (error) {
    console.error('Test failed:', error);
    res.status(500).json({ 
      error: 'Test failed', 
      details: error.message,
      stack: error.stack
    });
  }
});

// Health check
app.get('/test/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Start test server
app.listen(PORT, () => {
  console.log(`Test server running on port ${PORT}`);
  console.log(`Test users endpoint: http://localhost:${PORT}/test/users`);
  console.log(`Health check: http://localhost:${PORT}/test/health`);
}); 