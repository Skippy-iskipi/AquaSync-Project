const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Import routes
const datasetsRouter = require('./routes/datasets');
const modelsRouter = require('./routes/models');
const fishRouter = require('./routes/fish');
const usersRouter = require('./routes/users');

// Initialize express app
const app = express();
const PORT = process.env.PORT || 8080;

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Middleware
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  console.log('Headers:', req.headers);
  next();
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Global error handler:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  console.log('Authenticating request...');
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    console.log('No token provided');
    return res.status(401).json({ message: 'Access denied. No token provided.' });
  }
  
  try {
    console.log('Verifying token...');
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error) {
      console.error('Token verification error:', error);
      throw error;
    }
    
    console.log('Token verified for user:', user.id);
    req.user = user;
    next();
  } catch (error) {
    console.error('Auth error:', error);
    return res.status(403).json({ message: 'Invalid or expired token.' });
  }
};

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Use routers
app.use('/api/admin/datasets', datasetsRouter);
app.use('/api/admin/model', modelsRouter);
app.use('/api/admin/fish', fishRouter);
app.use('/api/admin/users', usersRouter);

// Start server
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Handle server errors
server.on('error', (error) => {
  console.error('Server error:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});