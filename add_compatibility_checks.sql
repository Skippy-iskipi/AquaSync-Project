-- Add compatibility_checks_count column to profiles table
ALTER TABLE profiles ADD COLUMN compatibility_checks_count INTEGER DEFAULT 0;

-- Update RLS policies to allow users to read and update their own compatibility_checks_count
CREATE POLICY "Users can read their own compatibility_checks_count"
  ON profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own compatibility_checks_count"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id); 