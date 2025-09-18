-- Update diet_calculations table to match the required structure
-- This script adds the missing columns and removes unused ones

-- Add new columns for the required data structure
ALTER TABLE diet_calculations 
ADD COLUMN IF NOT EXISTS feeding_schedule TEXT,
ADD COLUMN IF NOT EXISTS total_food_per_feeding TEXT,
ADD COLUMN IF NOT EXISTS per_fish_breakdown JSONB,
ADD COLUMN IF NOT EXISTS recommended_food_types TEXT[],
ADD COLUMN IF NOT EXISTS feeding_tips TEXT;

-- Remove columns that are no longer needed
ALTER TABLE diet_calculations 
DROP COLUMN IF EXISTS total_portion_range,
DROP COLUMN IF EXISTS feedings_per_day;

-- Update the table structure to match the new requirements
-- The table should now have these columns:
-- id, user_id, fish_selections, total_portion, portion_details, 
-- compatibility_issues, feeding_notes, feeding_schedule, 
-- total_food_per_feeding, per_fish_breakdown, recommended_food_types, 
-- feeding_tips, date_calculated, saved_plan, created_at, updated_at

-- Add comments to document the new structure
COMMENT ON COLUMN diet_calculations.feeding_schedule IS 'Feeding schedule information (e.g., "1-2 times per day")';
COMMENT ON COLUMN diet_calculations.total_food_per_feeding IS 'Total food amount per feeding (e.g., "166g for 2 koi and 2 goldfish")';
COMMENT ON COLUMN diet_calculations.per_fish_breakdown IS 'JSON object with per-fish feeding breakdown';
COMMENT ON COLUMN diet_calculations.recommended_food_types IS 'Array of recommended food types';
COMMENT ON COLUMN diet_calculations.feeding_tips IS 'Feeding tips and recommendations';
