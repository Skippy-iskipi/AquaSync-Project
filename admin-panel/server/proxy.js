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

// Proxy WebSocket connections for training logs
const wsProxy = createProxyMiddleware({
  target: 'http://localhost:8000',
  changeOrigin: true,
  ws: true, // Enable WebSocket proxying
  pathRewrite: { '^/ws': '/ws' }, // Keep the path as is
  logLevel: 'debug', // More detailed logging
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying WebSocket request to: ${proxyReq.method} ${proxyReq.path}`);
  },
  onProxyReqWs: (proxyReq, req, socket, options, head) => {
    console.log(`Proxying WebSocket upgrade to: ${req.url}`);
  },
  onOpen: (proxySocket) => {
    console.log('WebSocket connection opened');
  },
  onClose: (res, socket, head) => {
    console.log('WebSocket connection closed');
  },
  onError: (err, req, res) => {
    console.error('WebSocket Proxy Error:', err);
    if (res && res.status) {
      res.status(500).json({ error: 'WebSocket proxy error', details: err.message });
    }
  }
});

app.use('/ws', wsProxy);

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

// Upgrade HTTP server to handle WebSocket connections
server.on('upgrade', (req, socket, head) => {
  console.log(`WebSocket upgrade request for: ${req.url}`);
  
  // Check if the request is for our WebSocket endpoint
  if (req.url.startsWith('/ws')) {
    console.log('Upgrading WebSocket connection for training logs');
    
    // Use the already configured wsProxy
    wsProxy.upgrade(req, socket, head);
    
    // Handle socket errors
    socket.on('error', (err) => {
      console.error('WebSocket socket error:', err);
    });
    
    // Handle socket close
    socket.on('close', () => {
      console.log('WebSocket socket closed');
    });
  } else {
    console.log(`No handler for WebSocket upgrade to ${req.url}`);
    socket.destroy();
  }
});

// Start the server
server.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
  console.log(`Proxying admin requests to http://localhost:8080`);
  console.log(`Proxying API requests to http://localhost:8000`);
  console.log(`Proxying WebSocket connections to http://localhost:8000`);
});
