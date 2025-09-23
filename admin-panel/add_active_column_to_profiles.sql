-- Add active column to profiles table if it doesn't exist
-- Run this in your Supabase SQL Editor

-- Add active column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;

-- Update existing profiles to be active by default
UPDATE profiles 
SET active = true 
WHERE active IS NULL;

-- Add an index for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_active ON profiles(active);

-- Add a comment to the column
COMMENT ON COLUMN profiles.active IS 'User account status: true = active, false = inactive';
