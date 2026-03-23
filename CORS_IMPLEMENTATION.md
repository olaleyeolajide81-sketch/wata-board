# CORS Configuration Implementation

## Overview

This document describes the CORS (Cross-Origin Resource Sharing) configuration implemented for the Wata-Board project to resolve issue #8. The implementation provides secure CORS policies with environment-based settings for development and production deployments.

## Implementation Details

### 1. Server Setup

Created a new Express.js server (`src/server.ts`) with comprehensive CORS middleware configuration that includes:

- **Dynamic Origin Validation**: Allows configured origins based on environment
- **Development Flexibility**: Automatically allows localhost origins in development
- **Production Security**: Restricts to explicitly allowed origins in production
- **Credential Support**: Enables cookies and authentication headers
- **Proper Headers**: Configures allowed methods, headers, and exposed headers
- **Caching**: Sets preflight request cache for optimal performance

### 2. CORS Configuration Options

```typescript
const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    // Dynamic origin validation based on environment
    const allowedOrigins = getAllowedOrigins();
    
    if (process.env.NODE_ENV === 'development') {
      // Allow localhost with any port in development
      if (origin?.startsWith('http://localhost:') || origin?.startsWith('http://127.0.0.1:')) {
        return callback(null, true);
      }
    }
    
    // Check against allowed origins list
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Origin', 'X-Requested-With', 'Content-Type', 'Accept',
    'Authorization', 'Cache-Control', 'Pragma'
  ],
  exposedHeaders: ['X-Total-Count', 'X-Rate-Limit-Remaining'],
  maxAge: 86400 // 24 hours
};
```

### 3. Environment-Based Configuration

#### Development Environment
- Automatically allows `localhost` and `127.0.0.1` on any port
- Includes default development origins: `http://localhost:3000`, `http://localhost:5173`
- Relaxed security for easier development

#### Production Environment
- Restricts to explicitly configured origins only
- Uses `ALLOWED_ORIGINS` environment variable for whitelist
- Includes `FRONTEND_URL` if specified
- Enhanced security for production deployments

### 4. Environment Variables

Add these to your `.env` file:

```bash
# CORS Configuration
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
FRONTEND_URL=https://your-frontend-domain.com

# Server Configuration
NODE_ENV=production
PORT=3001
```

### 5. API Endpoints

The server provides the following CORS-enabled endpoints:

#### `POST /api/payment`
- Process utility payments with rate limiting
- Includes rate limit headers in responses
- Proper error handling for CORS violations

#### `GET /api/rate-limit/:userId`
- Get rate limit status for users
- CORS headers included for cross-origin requests

#### `GET /api/payment/:meterId`
- Retrieve payment information for meters
- Secure CORS configuration for sensitive data

#### `GET /health`
- Health check endpoint
- Always accessible for monitoring

### 6. Security Features

#### Rate Limiting Integration
- CORS headers include rate limit information
- `X-Rate-Limit-Remaining` header in responses
- Proper HTTP status codes for rate limit errors (429)

#### Error Handling
- Specific CORS error handling with 403 status
- Detailed logging for CORS violations
- Graceful degradation for unsupported origins

#### Security Headers
- Helmet.js middleware for additional security
- Content Security Policy headers
- X-Frame-Options, X-Content-Type-Options, etc.

### 7. Deployment Considerations

#### Development Deployment
```bash
# Set development environment
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

# Start development server
npm run dev
```

#### Production Deployment
```bash
# Set production environment
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
FRONTEND_URL=https://your-frontend-domain.com

# Start production server
npm start
```

#### Docker Deployment
```dockerfile
# Environment variables in Docker
ENV NODE_ENV=production
ENV ALLOWED_ORIGINS=https://yourdomain.com
ENV PORT=3001
```

### 8. Testing CORS Configuration

#### Test Cross-Origin Requests
```javascript
// Test from browser console
fetch('http://localhost:3001/api/payment', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include',
  body: JSON.stringify({
    meter_id: 'TEST-001',
    amount: 10,
    userId: 'test-user'
  })
})
.then(response => response.json())
.then(data => console.log(data));
```

#### Test CORS Headers
```bash
# Test preflight request
curl -X OPTIONS http://localhost:3001/api/payment \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v
```

### 9. Troubleshooting

#### Common CORS Issues

1. **"Not allowed by CORS" Error**
   - Check if origin is in `ALLOWED_ORIGINS`
   - Verify `NODE_ENV` is set correctly
   - Ensure frontend URL is properly configured

2. **Credentials Not Working**
   - Ensure `credentials: true` in CORS config
   - Frontend must include `credentials: 'include'` in fetch requests

3. **Preflight Requests Failing**
   - Check allowed methods and headers
   - Verify `maxAge` is set appropriately
   - Ensure proper HTTP status codes (200 for preflight)

#### Debug Logging
The server logs CORS violations for debugging:
```bash
2024-01-01T12:00:00.000Z - OPTIONS /api/payment - 127.0.0.1
CORS: Origin https://malicious-site.com not allowed
```

### 10. Migration from Standalone Script

The previous standalone script (`src/index.ts`) is now integrated into the server. To migrate:

1. **Update Dependencies**: New Express.js server with CORS middleware
2. **Environment Variables**: Add CORS configuration to `.env`
3. **API Integration**: Frontend should call API endpoints instead of direct script execution
4. **Deployment**: Use `npm start` instead of `npx ts-node src/index.ts`

### 11. Benefits

#### Security Improvements
- ✅ Prevents unauthorized cross-origin requests
- ✅ Configurable origin whitelist
- ✅ Environment-based security policies
- ✅ Proper credential handling

#### Development Experience
- ✅ Automatic localhost support in development
- ✅ Clear error messages for CORS issues
- ✅ Comprehensive logging for debugging
- ✅ Flexible configuration options

#### Production Readiness
- ✅ Scalable Express.js architecture
- ✅ Proper HTTP status codes
- ✅ Rate limiting integration
- ✅ Security headers with Helmet.js

## Conclusion

This CORS implementation resolves issue #8 by providing:
1. **Secure CORS policies** with environment-based configuration
2. **Development flexibility** with automatic localhost support
3. **Production security** with explicit origin whitelisting
4. **Comprehensive API** with proper error handling and logging
5. **Easy deployment** with Docker and environment variable support

The implementation follows security best practices while maintaining developer productivity and deployment flexibility.
