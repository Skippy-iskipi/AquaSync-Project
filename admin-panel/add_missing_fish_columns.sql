-- Add missing columns to fish_species table
-- This script adds the columns that are missing from the database

-- Add the missing columns if they don't exist
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS tank_level VARCHAR(50);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS care_level VARCHAR(50);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS overfeeding_risks TEXT;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS bioload DECIMAL(3,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS portion_grams DECIMAL(5,2);

-- Verify the columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'fish_species' 
AND column_name IN ('tank_level', 'care_level', 'description', 'overfeeding_risks', 'bioload', 'portion_grams')
ORDER BY column_name;
