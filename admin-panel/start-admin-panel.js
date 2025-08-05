#!/usr/bin/env node

const { spawn } = require('child_process');
const http = require('http');

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

const log = (color, message) => {
  console.log(`${colors[color]}${message}${colors.reset}`);
};

// Check if server is running
const checkServer = () => {
  return new Promise((resolve) => {
    const req = http.request({
      hostname: 'localhost',
      port: 8080,
      path: '/api/admin/health',
      method: 'GET',
      timeout: 5000
    }, (res) => {
      if (res.statusCode === 200) {
        log('green', '✅ Server is already running on port 8080');
        resolve(true);
      } else {
        log('yellow', `⚠️  Server responded with status ${res.statusCode}`);
        resolve(false);
      }
    });

    req.on('error', () => {
      log('red', '❌ Server is not running on port 8080');
      resolve(false);
    });

    req.on('timeout', () => {
      log('red', '⏰ Server connection timed out');
      resolve(false);
    });

    req.end();
  });
};

// Start server
const startServer = () => {
  log('blue', '🚀 Starting server...');
  
  const server = spawn('npm', ['start'], {
    cwd: './admin-panel/server',
    stdio: 'pipe',
    shell: true
  });

  server.stdout.on('data', (data) => {
    const output = data.toString();
    if (output.includes('Server running on port 8080')) {
      log('green', '✅ Server started successfully!');
    }
    process.stdout.write(output);
  });

  server.stderr.on('data', (data) => {
    process.stderr.write(data);
  });

  server.on('error', (error) => {
    log('red', `❌ Failed to start server: ${error.message}`);
  });

  return server;
};

// Start client
const startClient = () => {
  log('blue', '🚀 Starting client...');
  
  const client = spawn('npm', ['start'], {
    cwd: './admin-panel/client',
    stdio: 'pipe',
    shell: true
  });

  client.stdout.on('data', (data) => {
    const output = data.toString();
    if (output.includes('Local:')) {
      log('green', '✅ Client started successfully!');
      log('cyan', '🌐 Admin panel should be available at: http://localhost:3000');
    }
    process.stdout.write(output);
  });

  client.stderr.on('data', (data) => {
    process.stderr.write(data);
  });

  client.on('error', (error) => {
    log('red', `❌ Failed to start client: ${error.message}`);
  });

  return client;
};

// Main function
const main = async () => {
  log('cyan', '🔧 AquaSync Admin Panel Startup');
  log('cyan', '================================');
  
  // Check if server is running
  const serverRunning = await checkServer();
  
  let serverProcess = null;
  
  if (!serverRunning) {
    log('yellow', '📋 Starting server...');
    serverProcess = startServer();
    
    // Wait a bit for server to start
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Check again
    const serverNowRunning = await checkServer();
    if (!serverNowRunning) {
      log('red', '❌ Server failed to start. Please check the server logs.');
      process.exit(1);
    }
  }
  
  // Start client
  log('yellow', '📋 Starting client...');
  const clientProcess = startClient();
  
  // Handle process termination
  process.on('SIGINT', () => {
    log('yellow', '\n🛑 Shutting down...');
    if (serverProcess) serverProcess.kill();
    if (clientProcess) clientProcess.kill();
    process.exit(0);
  });
  
  log('green', '\n🎉 Admin panel startup complete!');
  log('cyan', '📝 Press Ctrl+C to stop both server and client');
};

// Run the script
main().catch(error => {
  log('red', `❌ Startup failed: ${error.message}`);
  process.exit(1);
}); 