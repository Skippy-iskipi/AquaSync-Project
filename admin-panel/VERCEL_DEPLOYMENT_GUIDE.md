c# AquaSync Admin Panel - Vercel Deployment Guide

This guide will help you deploy your AquaSync Admin Panel to Vercel with both frontend and backend API.

## Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **Supabase Project**: Ensure your Supabase project is set up and running
3. **GitHub Repository**: Your code should be in a GitHub repository
4. **Node.js**: Version 16+ (for local testing)

## Step 1: Prepare Your Repository

### 1.1 Ensure All Files Are Committed
```bash
cd admin-panel
git add .
git commit -m "Prepare for Vercel deployment"
git push origin main
```

### 1.2 Verify Build Process
Test the build process locally:
```bash
# Install dependencies
npm install

# Build the project
npm run build

# Test the build
npx serve -s build
```

## Step 2: Deploy to Vercel

### 2.1 Connect Repository to Vercel

1. Go to [vercel.com](https://vercel.com) and sign in
2. Click "New Project"
3. Import your GitHub repository
4. Select the `admin-panel` folder as the root directory

### 2.2 Configure Build Settings

Vercel should automatically detect this as a React app. The build settings should be:
- **Framework Preset**: Create React App
- **Root Directory**: `admin-panel`
- **Build Command**: `npm run build`
- **Output Directory**: `build`
- **Install Command**: `npm install`

### 2.3 Set Environment Variables

In your Vercel project settings, go to "Environment Variables" and add:

#### Frontend Variables:
```
REACT_APP_SUPABASE_URL=your-supabase-url
REACT_APP_SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
REACT_APP_API_URL=https://your-app-name.vercel.app
```

#### Backend Variables:
```
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
NODE_ENV=production
PORT=5000
```

**Important Notes:**
- Replace `your-app-name.vercel.app` with your actual Vercel domain
- Use a strong, unique JWT_SECRET (at least 32 characters)
- Get your Supabase credentials from your Supabase project dashboard

### 2.4 Deploy

1. Click "Deploy" in Vercel
2. Wait for the build to complete
3. Your admin panel will be available at `https://your-app-name.vercel.app`

## Step 3: Configure Custom Domain (Optional)

1. In Vercel dashboard, go to your project
2. Click "Domains"
3. Add your custom domain
4. Update the `REACT_APP_API_URL` environment variable to match your custom domain

## Step 4: Database Setup

### 4.1 Create Admin Users Table

Run this SQL in your Supabase SQL editor:

```sql
-- Create admin users table
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Insert default admin user (password: admin123)
INSERT INTO admin_users (username, password_hash, email, role)
VALUES ('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@aquasync.com', 'admin')
ON CONFLICT (username) 
DO UPDATE SET password_hash = EXCLUDED.password_hash;
```

### 4.2 Verify Required Tables

Ensure these tables exist in your Supabase database:
- `fish_species`
- `profiles`
- `tanks`
- `tank_fish`
- `admin_users` (created above)

## Step 5: Test Your Deployment

### 5.1 Frontend Test
1. Visit your Vercel URL
2. You should see the admin panel login page
3. Try logging in with default credentials:
   - **Username**: admin
   - **Password**: admin123

### 5.2 API Test
1. Visit `https://your-app-name.vercel.app/api/health`
2. You should see a JSON response with status "OK"

### 5.3 Full Functionality Test
1. Login to the admin panel
2. Test dashboard functionality
3. Test fish management features
4. Test user management features

## Troubleshooting

### Common Issues

#### 1. CORS Errors
**Problem**: API calls fail with CORS errors
**Solution**: 
- Verify `REACT_APP_API_URL` matches your Vercel domain
- Check that CORS configuration in `api/server.js` includes your domain

#### 2. Environment Variables Not Working
**Problem**: App can't access environment variables
**Solution**:
- Ensure variables are set in Vercel dashboard
- Redeploy after adding new variables
- Check variable names match exactly (case-sensitive)

#### 3. Build Failures
**Problem**: Vercel build fails
**Solution**:
- Check build logs in Vercel dashboard
- Ensure all dependencies are in `package.json`
- Test build locally with `npm run build`

#### 4. Database Connection Issues
**Problem**: Can't connect to Supabase
**Solution**:
- Verify Supabase URL and service role key
- Check Supabase project is active
- Ensure RLS policies allow service role access

#### 5. API Routes Not Working
**Problem**: API endpoints return 404
**Solution**:
- Check `vercel.json` configuration
- Ensure API files are in correct location
- Verify route patterns in `vercel.json`

### Debug Steps

1. **Check Vercel Function Logs**:
   - Go to Vercel dashboard → Functions tab
   - Look for error logs

2. **Test API Endpoints Directly**:
   - Use Postman or curl to test API endpoints
   - Check response headers and status codes

3. **Verify Environment Variables**:
   - Use Vercel CLI: `vercel env ls`
   - Check if variables are available at runtime

## Security Considerations

### 1. Change Default Credentials
```sql
-- Update admin password (replace with your secure password)
UPDATE admin_users 
SET password_hash = '$2a$10$your-new-hash-here' 
WHERE username = 'admin';
```

### 2. Use Strong JWT Secret
- Generate a strong JWT secret (32+ characters)
- Use a password manager to generate random strings
- Never commit secrets to version control

### 3. Enable RLS Policies
Ensure your Supabase tables have proper Row Level Security policies.

### 4. Monitor Usage
- Set up Vercel monitoring
- Monitor API usage and errors
- Set up alerts for unusual activity

## Maintenance

### Regular Updates
1. Keep dependencies updated
2. Monitor Vercel and Supabase usage
3. Review and rotate secrets periodically
4. Monitor error logs

### Backup Strategy
1. Regular database backups in Supabase
2. Keep code in version control
3. Document any custom configurations

## Support

If you encounter issues:
1. Check Vercel deployment logs
2. Check Supabase logs
3. Test locally first
4. Review this guide for common solutions

## Default Access

**URL**: `https://your-app-name.vercel.app`
**Username**: admin
**Password**: admin123

⚠️ **Important**: Change the default password immediately after deployment!
