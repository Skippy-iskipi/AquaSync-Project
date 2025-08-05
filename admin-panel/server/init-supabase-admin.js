const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function initializeSupabaseAdmin() {
  try {
    console.log('Creating admin user in Supabase...');

    // First, create the user in auth.users
    const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
      email: 'admin@aquasync.com',
      password: 'adminaquasync123',
      email_confirm: true
    });

    if (authError) {
      throw authError;
    }

    console.log('Auth user created:', authUser.user.id);

    // Then create the admin record in admin_users table
    const { data: adminUser, error: adminError } = await supabase
      .from('admin_users')
      .insert([
        {
          id: authUser.user.id,
          role: 'admin',
          username: 'admin',
          email: 'admin@aquasync.com'
        }
      ])
      .select()
      .single();

    if (adminError) {
      throw adminError;
    }

    console.log('Admin user created successfully!');
    console.log('Email:', 'admin@aquasync.com');
    console.log('Password: adminaquasync123');
    console.log('User ID:', adminUser.id);

  } catch (error) {
    if (error.code === '23505') { // Unique violation
      console.log('Admin user already exists');
    } else {
      console.error('Error creating admin user:', error);
    }
  }
}

initializeSupabaseAdmin();