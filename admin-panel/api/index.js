const express = require('express');
const cors = require('cors');
require('dotenv').config();

// Import existing routers from the server code
const datasetsRouter = require('../server/routes/datasets');
const modelsRouter = require('../server/routes/models');
const fishRouter = require('../server/routes/fish');
const usersRouter = require('../server/routes/users');

// Create express app (do NOT call app.listen in serverless)
const app = express();

// CORS: since frontend and API share the same origin on Vercel, allow same-origin and common methods
app.use(cors({
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
}));

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', ts: new Date().toISOString() });
});

// Mount routers to match the client baseURL '/api/admin'
app.use('/api/admin/datasets', datasetsRouter);
app.use('/api/admin/model', modelsRouter);
app.use('/api/admin/fish', fishRouter);
app.use('/api/admin/users', usersRouter);

// Export a (req, res) handler for @vercel/node
module.exports = (req, res) => {
  return app(req, res);
};
