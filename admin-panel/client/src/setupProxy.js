const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: 'http://localhost:8080',
      changeOrigin: true,
      secure: false,
      logLevel: 'debug',
      pathRewrite: false, // Don't rewrite paths
      onProxyReq: (proxyReq, req, res) => {
        // Log the request details
        console.log('Proxy Request:', {
          originalUrl: req.originalUrl,
          targetUrl: `${proxyReq.protocol}//${proxyReq.host}${proxyReq.path}`,
          method: req.method,
          headers: req.headers
        });

        if (['POST', 'PUT'].includes(req.method) && req.body) {
          const bodyData = JSON.stringify(req.body);
          proxyReq.setHeader('Content-Type', 'application/json');
          proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
          proxyReq.write(bodyData);
        }
      },
      onProxyRes: (proxyRes, req, res) => {
        // Log the response details
        console.log('Proxy Response:', {
          path: req.path,
          status: proxyRes.statusCode,
          headers: proxyRes.headers
        });

        if (proxyRes.statusCode >= 400) {
          let responseBody = '';
          proxyRes.on('data', function(chunk) {
            responseBody += chunk;
          });
          proxyRes.on('end', function() {
            console.log('Error Response Body:', responseBody);
          });
        }
      },
      onError: (err, req, res) => {
        console.error('Proxy Error:', {
          error: err,
          message: err.message,
          code: err.code,
          originalUrl: req.originalUrl,
          path: req.path
        });
        
        res.status(500).json({
          error: 'Proxy Error',
          message: err.message,
          code: err.code,
          path: req.path
        });
      }
    })
  );
};