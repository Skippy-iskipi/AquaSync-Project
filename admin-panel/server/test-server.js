// Test Server Connection
// This script tests if the server is running and accessible

const http = require('http');

const testServer = () => {
  console.log('Testing server connection...');
  
  const options = {
    hostname: 'localhost',
    port: 8080,
    path: '/api/admin/health',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers: ${JSON.stringify(res.headers)}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('Response:', data);
      if (res.statusCode === 200) {
        console.log('✅ Server is running and accessible!');
      } else {
        console.log('❌ Server responded with error status');
      }
    });
  });

  req.on('error', (err) => {
    console.error('❌ Connection error:', err.message);
    console.log('Make sure the server is running on port 8080');
  });

  req.end();
};

// Test users endpoint (without auth)
const testUsersEndpoint = () => {
  console.log('\nTesting users endpoint...');
  
  const options = {
    hostname: 'localhost',
    port: 8080,
    path: '/api/admin/users',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log('Response:', data);
      if (res.statusCode === 401) {
        console.log('✅ Server is working (401 expected without auth)');
      } else if (res.statusCode === 200) {
        console.log('✅ Users endpoint is accessible!');
      } else {
        console.log('❌ Unexpected response');
      }
    });
  });

  req.on('error', (err) => {
    console.error('❌ Connection error:', err.message);
  });

  req.end();
};

// Run tests
testServer();
setTimeout(testUsersEndpoint, 1000);

console.log('\nTo start the server, run:');
console.log('cd admin-panel/server && npm start'); 