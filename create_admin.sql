-- Drop existing table if it exists without the right columns
DROP TABLE IF EXISTS admin_users;

-- Create admin users table with proper structure
CREATE TABLE admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Enable RLS on admin_users table
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for admin_users table
-- Policy 1: Allow service role to do everything (for API access)
CREATE POLICY "Service role can manage admin users" ON admin_users
    FOR ALL USING (auth.role() = 'service_role');

-- Policy 2: Allow authenticated admin users to read their own data
CREATE POLICY "Admin users can read own data" ON admin_users
    FOR SELECT USING (auth.uid()::text = id::text OR auth.role() = 'service_role');

-- Policy 3: Allow admin users to update their own data
CREATE POLICY "Admin users can update own data" ON admin_users
    FOR UPDATE USING (auth.uid()::text = id::text OR auth.role() = 'service_role');

-- Grant necessary permissions to service role
GRANT ALL ON admin_users TO service_role;
GRANT USAGE, SELECT ON SEQUENCE admin_users_id_seq TO service_role;

-- Insert default admin user (password is plain text for demo, will be handled by auth middleware)
INSERT INTO admin_users (username, password_hash, email, role)
VALUES ('admin', 'admin123', 'admin@aquasync.com', 'admin');