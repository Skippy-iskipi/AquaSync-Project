-- Add email column to profiles table and update trigger
-- Run this in your Supabase SQL Editor

-- Step 1: Add email column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Step 2: Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS profiles_email_idx ON profiles(email);

-- Step 3: Update existing profiles with email from auth.users
UPDATE profiles 
SET email = auth.users.email 
FROM auth.users 
WHERE profiles.id = auth.users.id 
AND profiles.email IS NULL;

-- Step 4: Update the trigger function to include email
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, tier_plan, email)
  VALUES (
    NEW.id,
    'free',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Update RLS policies to include email column
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

CREATE POLICY "Users can view their own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Step 6: Grant necessary permissions
GRANT SELECT ON profiles TO authenticated;
GRANT INSERT ON profiles TO authenticated;
GRANT UPDATE ON profiles TO authenticated; 