-- Migration script to update compatibility_results table for multi-fish compatibility
-- This script removes old columns and adds new ones to support multiple fish selection

-- Step 1: Add new columns
ALTER TABLE compatibility_results 
ADD COLUMN selected_fish JSONB,
ADD COLUMN compatibility_level TEXT,
ADD COLUMN pair_analysis JSONB,
ADD COLUMN tankmate_recommendations JSONB;

-- Step 2: Migrate existing data to new format
-- Convert old fish1_name, fish2_name to selected_fish JSONB format
UPDATE compatibility_results 
SET selected_fish = jsonb_build_object(
  fish1_name, 1,
  fish2_name, 1
),
compatibility_level = CASE 
  WHEN is_compatible = true THEN 'compatible'
  ELSE 'incompatible'
END,
pair_analysis = jsonb_build_object(
  'pairs', jsonb_build_array(
    jsonb_build_object(
      'fish1', fish1_name,
      'fish2', fish2_name,
      'compatibility', CASE 
        WHEN is_compatible = true THEN 'compatible'
        ELSE 'incompatible'
      END,
      'reasons', reasons
    )
  )
),
tankmate_recommendations = '{}'::jsonb
WHERE selected_fish IS NULL;

-- Step 3: Drop old columns that are no longer needed
ALTER TABLE compatibility_results 
DROP COLUMN IF EXISTS fish1_name,
DROP COLUMN IF EXISTS fish1_image_path,
DROP COLUMN IF EXISTS fish2_name,
DROP COLUMN IF EXISTS fish2_image_path,
DROP COLUMN IF EXISTS saved_plan;

-- Step 4: Add constraints and indexes for better performance
ALTER TABLE compatibility_results 
ALTER COLUMN selected_fish SET NOT NULL,
ALTER COLUMN compatibility_level SET NOT NULL;

-- Add index on selected_fish for better query performance
CREATE INDEX IF NOT EXISTS idx_compatibility_results_selected_fish 
ON compatibility_results USING GIN (selected_fish);

-- Add index on compatibility_level for filtering
CREATE INDEX IF NOT EXISTS idx_compatibility_results_compatibility_level 
ON compatibility_results (compatibility_level);

-- Add index on user_id and date_checked for user history queries
CREATE INDEX IF NOT EXISTS idx_compatibility_results_user_date 
ON compatibility_results (user_id, date_checked DESC);

-- Step 5: Add comments to document the new structure
COMMENT ON COLUMN compatibility_results.selected_fish IS 'JSONB object storing selected fish names as keys and quantities as values';
COMMENT ON COLUMN compatibility_results.compatibility_level IS 'Overall compatibility level: compatible, conditional, or incompatible';
COMMENT ON COLUMN compatibility_results.pair_analysis IS 'JSONB object storing individual pair-by-pair compatibility analysis';
COMMENT ON COLUMN compatibility_results.tankmate_recommendations IS 'JSONB object storing tankmate recommendations for each selected fish';

-- Step 6: Verify the migration
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'compatibility_results' 
ORDER BY ordinal_position;
