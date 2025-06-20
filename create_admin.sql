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
VALUES ('admin', 'admin123', 'admin@aquasync.com', 'admin')
ON CONFLICT (username) 
DO UPDATE SET password_hash = EXCLUDED.password_hash; 