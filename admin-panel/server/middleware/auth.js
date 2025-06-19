const jwt = require('jsonwebtoken');
const db = require('../db/db');

const JWT_SECRET = process.env.JWT_SECRET || 'aquasync-admin-secret';

// Middleware to authenticate admin users
const authenticateAdmin = async (req, res, next) => {
  try {
    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Check if user exists
    const result = await db.query(
      'SELECT * FROM admin_users WHERE id = $1', 
      [decoded.userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid authentication' });
    }

    // Add user to request
    const user = result.rows[0];
    delete user.password_hash; // Don't send password hash to client
    
    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    console.error('Auth error:', error);
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
        // Log the activity
        await db.query(
          'INSERT INTO admin_activity(admin_id, action_type, details, ip_address) VALUES($1, $2, $3, $4)',
          [
            req.user.id,
            req.method + ' ' + req.originalUrl,
            JSON.stringify({
              body: req.body,
              params: req.params,
              query: req.query,
              statusCode: res.statusCode
            }),
            req.ip
          ]
        );
      } catch (error) {
        console.error('Error logging activity:', error);
      }
    }
    
    // Call the original end function
    originalEnd.call(this, chunk, encoding);
  };
  
  next();
};

/**
 * Authentication middleware for protected routes
 * Verifies JWT token from Authorization header
 */
const protectRoute = (req, res, next) => {
  // Get token from header
  const authHeader = req.header('Authorization');
  
  // Check if no token
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Access denied. No token provided' });
  }
  
  // Extract token
  const token = authHeader.split(' ')[1];
  
  try {
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Add user from payload
    req.user = decoded;
    
    // Log for debugging
    console.log('Token verified successfully:', decoded);
    
    next();
  } catch (err) {
    console.error('Token verification error:', err);
    
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token has expired' });
    }
    
    res.status(401).json({ error: 'Invalid token' });
  }
};

module.exports = {
  authenticateAdmin,
  logActivity,
  generateToken: (userId) => jwt.sign({ userId }, JWT_SECRET, { expiresIn: '8h' }),
  protectRoute
}; 