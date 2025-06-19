const express = require('express');
const router = express.Router();
const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { check, validationResult } = require('express-validator');

// Environment variables
const JWT_SECRET = process.env.JWT_SECRET || 'aquasync-admin-secret';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1d';

// Validation middleware
const loginValidation = [
  check('username').notEmpty().withMessage('Username is required'),
  check('password').notEmpty().withMessage('Password is required')
];

// Login route
router.post('/login', loginValidation, async (req, res) => {
  // Check validation errors
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { username, password } = req.body;
    
    // Get user from database
    const { rows } = await db.query(
      'SELECT * FROM admin_users WHERE username = $1',
      [username]
    );
    
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const user = rows[0];
    
    // Compare passwords
    const isMatch = await bcrypt.compare(password, user.password);
    
    if (!isMatch) {
      // Log failed login attempt
      await db.query(
        'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
        [user.id, 'FAILED_LOGIN', JSON.stringify({ ip: req.ip })]
      );
      
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // Create JWT token
    const payload = {
      id: user.id,
      username: user.username,
      role: user.role
    };
    
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    
    // Log successful login
    await db.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [user.id, 'LOGIN', JSON.stringify({ ip: req.ip })]
    );
    
    // Update last login timestamp
    await db.query(
      'UPDATE admin_users SET last_login = NOW() WHERE id = $1',
      [user.id]
    );
    
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        email: user.email,
        name: user.name
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Change password route
router.put('/change-password', async (req, res) => {
  try {
    // Verify user is authenticated
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    const { currentPassword, newPassword } = req.body;
    
    // Validate input
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }
    
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters long' });
    }
    
    // Get user from database
    const { rows } = await db.query(
      'SELECT * FROM admin_users WHERE id = $1',
      [req.user.id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const user = rows[0];
    
    // Verify current password
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    
    if (!isMatch) {
      return res.status(400).json({ error: 'Current password is incorrect' });
    }
    
    // Hash new password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);
    
    // Update password in database
    await db.query(
      'UPDATE admin_users SET password = $1, updated_at = NOW() WHERE id = $2',
      [hashedPassword, req.user.id]
    );
    
    // Log password change
    await db.query(
      'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
      [req.user.id, 'PASSWORD_CHANGE', JSON.stringify({ ip: req.ip })]
    );
    
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error('Password change error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get current user
router.get('/me', async (req, res) => {
  try {
    // Verify user is authenticated
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    // Get user from database
    const { rows } = await db.query(
      'SELECT id, username, role, email, name, created_at, last_login FROM admin_users WHERE id = $1',
      [req.user.id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(rows[0]);
  } catch (err) {
    console.error('Get user error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Logout endpoint (just for activity logging)
router.post('/logout', async (req, res) => {
  try {
    // Log logout if user is authenticated
    if (req.user) {
      await db.query(
        'INSERT INTO admin_activity (admin_id, action_type, details) VALUES ($1, $2, $3)',
        [req.user.id, 'LOGOUT', JSON.stringify({ ip: req.ip })]
      );
    }
    
    res.json({ message: 'Logged out successfully' });
  } catch (err) {
    console.error('Logout error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router; 