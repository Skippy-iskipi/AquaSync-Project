const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const http = require('http');
const WebSocket = require('ws');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const dashboardRoutes = require('./routes/dashboard');
const fishRoutes = require('./routes/fish');
const userRoutes = require('./routes/users');

const app = express();
const PORT = process.env.PORT || 5000;

// Trust proxy for rate limiting and proper IP detection
app.set('trust proxy', 1);

// Security middleware
app.use(helmet());
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// CORS configuration
const allowedOrigins = process.env.NODE_ENV === 'production' 
  ? [
      process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'https://aquasync-admin.vercel.app',
      process.env.REACT_APP_API_URL || 'https://aquasync-admin.vercel.app'
    ]
  : ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:3001', 'http://localhost:5002', 'http://127.0.0.1:5002'];

app.use(cors({
  origin: allowedOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/fish', fishRoutes);
app.use('/api/users', userRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'production' ? {} : err.message
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ 
  server,
  path: '/ws'
});

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  console.log('📡 New WebSocket connection established');
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connection',
    message: 'Connected to AquaSync Admin Panel',
    timestamp: new Date().toISOString()
  }));

  // Handle incoming messages
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('📨 WebSocket message received:', data);
      
      // Echo back for now - you can add specific handlers here
      ws.send(JSON.stringify({
        type: 'response',
        data: data,
        timestamp: new Date().toISOString()
      }));
    } catch (error) {
      console.error('❌ WebSocket message error:', error);
    }
  });

  // Handle connection close
  ws.on('close', () => {
    console.log('📡 WebSocket connection closed');
  });

  // Handle errors
  ws.on('error', (error) => {
    console.error('❌ WebSocket error:', error);
  });
});

server.listen(PORT, () => {
  console.log(`🚀 Admin API Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📡 WebSocket server: ws://localhost:${PORT}/ws`);
});
