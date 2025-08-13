const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const path = require('path');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 3001;

// Enable CORS for all routes with more permissive settings
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Log all requests
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Proxy all admin-related API requests to the admin panel server (Node.js Express)
// This must come before the more specific routes
app.use('/api/admin', createProxyMiddleware({
  target: 'http://localhost:8080',
  changeOrigin: true,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying admin request to: ${proxyReq.method} ${proxyReq.path}`);
  },
  onError: (err, req, res) => {
    console.error('Admin Proxy Error:', err);
    res.status(500).json({ error: 'Admin proxy error', details: err.message });
  }
}));

// Proxy fish-images API requests to the backend server (Python FastAPI)
app.use('/api/fish-images', createProxyMiddleware({
  target: 'http://localhost:5000',
  changeOrigin: true,
  pathRewrite: {
    '^/api/fish-images': '/fish-images'
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying fish-images request to: ${proxyReq.method} ${proxyReq.path}`);
  },
  onError: (err, req, res) => {
    console.error('Fish Images Proxy Error:', err);
    res.status(500).json({ error: 'Fish images proxy error', details: err.message });
  }
}));

// Proxy all API requests to the backend server (Python FastAPI)
app.use('/api', createProxyMiddleware({
  target: 'http://localhost:8000',
  changeOrigin: true,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying API request to: ${proxyReq.method} ${proxyReq.path}`);
  },
  onError: (err, req, res) => {
    console.error('API Proxy Error:', err);
    res.status(500).json({ error: 'API proxy error', details: err.message });
  }
}));

// WebSocket proxy for training logs removed (no longer needed)
// Fallback route for debugging
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `The requested URL ${req.originalUrl} was not found on this server.`,
    availableRoutes: ['/api/admin/*', '/api/fish-images/*']
  });
});

// Create HTTP server instead of using app.listen directly
const server = http.createServer(app);

// WebSocket upgrade handler removed (no longer needed)

// Start the server
server.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
  console.log(`Proxying admin requests to http://localhost:8080`);
  console.log(`Proxying API requests to http://localhost:8000`);

});
