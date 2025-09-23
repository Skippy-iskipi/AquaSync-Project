const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const supabase = require('../config/supabase');

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';

// Middleware to verify admin authentication
const authenticateAdmin = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    console.log('Auth middleware - Token received:', token ? 'Present' : 'Missing');
    
    if (!token) {
      console.log('Auth middleware - No token provided');
      return res.status(401).json({ message: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    console.log('Auth middleware - Token decoded:', { id: decoded.id, username: decoded.username });
    
    // Verify admin user still exists and is active
    const { data: admin, error } = await supabase
      .from('admin_users')
      .select('*')
      .eq('id', decoded.id)
      .single();

    console.log('Auth middleware - Admin lookup result:', { admin, error });

    if (error || !admin) {
      console.log('Auth middleware - Admin not found or error:', error);
      return res.status(401).json({ message: 'Invalid token.' });
    }

    console.log('Auth middleware - Authentication successful');
    req.admin = admin;
    next();
  } catch (error) {
    console.log('Auth middleware - JWT verification error:', error.message);
    res.status(401).json({ message: 'Invalid token.' });
  }
};

// Hash password
const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};

// Compare password
const comparePassword = async (password, hashedPassword) => {
  return bcrypt.compare(password, hashedPassword);
};

// Generate JWT token
const generateToken = (adminId, username) => {
  return jwt.sign(
    { id: adminId, username },
    JWT_SECRET,
    { expiresIn: '24h' }
  );
};

module.exports = {
  authenticateAdmin,
  hashPassword,
  comparePassword,
  generateToken
};
