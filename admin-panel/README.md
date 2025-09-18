# AquaSync Admin Panel

A comprehensive admin panel for AquaSync system maintenance with React frontend and Node.js backend.

## Features

### 🎛️ Dashboard
- System-wide analytics and statistics
- User growth charts and fish distribution data
- System health monitoring
- Quick action buttons for common tasks

### 🐠 Fish Management
- Complete CRUD operations for fish species
- Advanced search and filtering
- Bulk operations support
- Fish compatibility data management
- Feeding portion calculations

### 👥 User Management
- User account management from Supabase Authentication
- Profile data editing and updates
- User activity monitoring
- Account activation/deactivation
- User statistics and tank information

### 🔒 Security Features
- JWT-based authentication
- Admin-only access control
- Rate limiting and request validation
- Secure API endpoints
- Password hashing and validation

## Tech Stack

### Frontend
- **React 18** - Modern React with hooks
- **Tailwind CSS** - Utility-first CSS framework
- **React Router** - Client-side routing
- **Recharts** - Data visualization
- **Heroicons** - Beautiful SVG icons
- **React Hot Toast** - Toast notifications

### Backend
- **Node.js** - JavaScript runtime
- **Express.js** - Web framework
- **Supabase** - Database and authentication
- **JWT** - Token-based authentication
- **bcryptjs** - Password hashing
- **Express Validator** - Input validation

## Installation

### Prerequisites
- Node.js 16+ 
- npm or yarn
- Supabase account and project

### Frontend Setup
1. Navigate to the admin panel directory:
   ```bash
   cd admin-panel
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy environment variables:
   ```bash
   cp env.example .env
   ```

4. Update `.env` with your Supabase credentials:
   ```
   REACT_APP_SUPABASE_URL=your-supabase-url
   REACT_APP_SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   REACT_APP_API_URL=http://localhost:5000
   ```

5. Start the development server:
   ```bash
   npm start
   ```

### Backend Setup
1. Navigate to the API directory:
   ```bash
   cd admin-panel/api
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create `.env` file with your configuration:
   ```
   SUPABASE_URL=your-supabase-url
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
   JWT_SECRET=your-super-secret-jwt-key
   NODE_ENV=development
   PORT=5000
   ```

4. Start the API server:
   ```bash
   npm run dev
   ```

## Database Setup

### Admin Users Table
Run the following SQL in your Supabase SQL editor:

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

-- Insert default admin user
INSERT INTO admin_users (username, password_hash, email, role)
VALUES ('admin', 'admin123', 'admin@aquasync.com', 'admin')
ON CONFLICT (username) 
DO UPDATE SET password_hash = EXCLUDED.password_hash;
```

### Required Tables
Ensure these tables exist in your Supabase database:
- `fish_species` - Fish species data
- `profiles` - User profiles
- `tanks` - User tanks
- `tank_fish` - Fish in tanks

## API Endpoints

### Authentication
- `POST /api/auth/login` - Admin login
- `GET /api/auth/verify` - Verify token

### Dashboard
- `GET /api/dashboard/stats` - System statistics
- `GET /api/dashboard/user-growth` - User growth data
- `GET /api/dashboard/fish-distribution` - Fish distribution
- `GET /api/dashboard/system-health` - System health

### Fish Management
- `GET /api/fish` - List fish species
- `GET /api/fish/:id` - Get fish by ID
- `POST /api/fish` - Create fish species
- `PUT /api/fish/:id` - Update fish species
- `DELETE /api/fish/:id` - Delete fish species
- `POST /api/fish/bulk-update` - Bulk operations

### User Management
- `GET /api/users` - List users
- `GET /api/users/:id` - Get user by ID
- `PUT /api/users/:id` - Update user
- `PATCH /api/users/:id/status` - Toggle user status
- `DELETE /api/users/:id` - Delete user
- `GET /api/users/:id/tanks` - Get user tanks
- `GET /api/users/:id/stats` - Get user statistics

## Default Credentials

**Username:** admin  
**Password:** admin123

⚠️ **Important:** Change the default password in production!

## Development

### Frontend Development
```bash
cd admin-panel
npm start
```
Runs on http://localhost:3000

### Backend Development
```bash
cd admin-panel/api
npm run dev
```
Runs on http://localhost:5000

### Building for Production
```bash
cd admin-panel
npm run build
```

## Security Considerations

1. **Change Default Credentials** - Update admin password immediately
2. **Environment Variables** - Never commit `.env` files
3. **JWT Secret** - Use a strong, unique JWT secret in production
4. **HTTPS** - Always use HTTPS in production
5. **Rate Limiting** - API includes rate limiting for security
6. **Input Validation** - All inputs are validated and sanitized

## Features in Detail

### Dashboard Analytics
- Real-time system statistics
- User growth trends over 30 days
- Popular fish species distribution
- System health monitoring with response times
- Quick action buttons for common admin tasks

### Fish Species Management
- Complete CRUD operations with validation
- Search by common name or scientific name
- Bulk update operations for efficiency
- Enhanced fish attributes including:
  - Water parameters (temperature, pH, hardness)
  - Behavioral attributes (activity level, tank zone)
  - Compatibility factors (fin vulnerability, territorial space)
  - Care requirements and feeding data

### User Account Management
- Integration with Supabase Authentication
- Profile management with validation
- Account activation/deactivation
- User statistics and activity tracking
- Tank and fish inventory per user

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure API server is running on port 5000
   - Check CORS configuration in server.js

2. **Authentication Issues**
   - Verify Supabase credentials in .env
   - Check admin_users table exists
   - Ensure JWT_SECRET is set

3. **Database Connection**
   - Verify SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
   - Check network connectivity to Supabase

### Logs and Debugging
- Frontend: Check browser console for errors
- Backend: Check server logs in terminal
- Database: Use Supabase dashboard for query logs

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the AquaSync ecosystem. Please refer to the main project license.
