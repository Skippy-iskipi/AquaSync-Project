const { Pool } = require('pg');
const bcrypt = require('bcrypt');
require('dotenv').config();

// Configure PostgreSQL connection
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'aquasync',
  password: 'aquasync',  // Use the same password as in server.js
  port: 5432,
});

async function initializeAdmin() {
  try {
    // Check if admin_users table exists
    const tableResult = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'admin_users'
      );
    `);
    
    if (!tableResult.rows[0].exists) {
      console.log("Creating admin_users table...");
      // Create the table if it doesn't exist
      await pool.query(`
        CREATE TABLE IF NOT EXISTS admin_users (
          id SERIAL PRIMARY KEY,
          username VARCHAR(50) UNIQUE NOT NULL,
          password_hash VARCHAR(255) NOT NULL,
          email VARCHAR(100),
          role VARCHAR(20) NOT NULL DEFAULT 'admin',
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          last_login TIMESTAMP WITH TIME ZONE
        );
      `);
      console.log("admin_users table created.");
    }

    // Check if admin_activity table exists
    const activityTableResult = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'admin_activity'
      );
    `);
    
    if (!activityTableResult.rows[0].exists) {
      console.log("Creating admin_activity table...");
      // Create the activity table if it doesn't exist
      await pool.query(`
        CREATE TABLE IF NOT EXISTS admin_activity (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES admin_users(id),
          action_type VARCHAR(255) NOT NULL,
          details TEXT,
          ip_address VARCHAR(45),
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
      `);
      console.log("admin_activity table created.");
    }

    // Check if admin user exists
    const adminExists = await pool.query(`
      SELECT COUNT(*) FROM admin_users WHERE username = 'admin';
    `);
    
    if (parseInt(adminExists.rows[0].count) === 0) {
      console.log("Creating admin user...");
      // Hash password
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash('admin123', salt);
      
      // Insert admin user
      await pool.query(`
        INSERT INTO admin_users (username, password_hash, role, email)
        VALUES ('admin', $1, 'admin', 'admin@aquasync.com');
      `, [hashedPassword]);
      
      console.log("Admin user created successfully!");
      console.log("Username: admin");
      console.log("Password: admin123");
    } else {
      console.log("Admin user already exists.");
    }
  } catch (error) {
    console.error("Error initializing admin user:", error);
  } finally {
    pool.end();
  }
}

initializeAdmin(); 