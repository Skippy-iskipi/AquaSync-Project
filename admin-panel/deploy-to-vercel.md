# Quick Vercel Deployment Steps

## 🚀 One-Click Deployment

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/your-username/your-repo&env=REACT_APP_SUPABASE_URL,REACT_APP_SUPABASE_SERVICE_ROLE_KEY,SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,JWT_SECRET)

## 📋 Manual Deployment Steps

### 1. Prepare Your Code
```bash
# Ensure all changes are committed
git add .
git commit -m "Ready for Vercel deployment"
git push origin main
```

### 2. Deploy to Vercel
1. Go to [vercel.com](https://vercel.com)
2. Click "New Project"
3. Import your repository
4. Set root directory to `admin-panel`
5. Add environment variables (see below)
6. Click "Deploy"

### 3. Environment Variables
Add these in Vercel project settings:

**Frontend:**
- `REACT_APP_SUPABASE_URL` = your-supabase-url
- `REACT_APP_SUPABASE_SERVICE_ROLE_KEY` = your-service-role-key
- `REACT_APP_API_URL` = https://your-app-name.vercel.app

**Backend:**
- `SUPABASE_URL` = your-supabase-url
- `SUPABASE_SERVICE_ROLE_KEY` = your-service-role-key
- `JWT_SECRET` = your-super-secret-jwt-key
- `NODE_ENV` = production

### 4. Database Setup
Run this SQL in Supabase:
```sql
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

INSERT INTO admin_users (username, password_hash, email, role)
VALUES ('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@aquasync.com', 'admin')
ON CONFLICT (username) DO NOTHING;
```

### 5. Test Your Deployment
- Visit your Vercel URL
- Login with: admin / admin123
- Test all features

## ✅ You're Done!
Your admin panel is now live on Vercel!
