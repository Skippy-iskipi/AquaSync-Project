-- Migration script to update existing tanks table to simplified schema
-- This removes unnecessary columns and keeps only the essential data

-- First, let's see what columns exist currently
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'tanks';

-- Add new columns if they don't exist
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS tank_name TEXT;
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS calculated_volume DECIMAL(10,2);
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS selected_fish JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_types JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS available_feed_qty JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS fish_feeding_data JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_duration_data JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS tank_size_notice JSONB DEFAULT '{}';

-- Migrate existing data to new column names
UPDATE tanks SET 
  tank_name = COALESCE(name, 'Unnamed Tank'),
  calculated_volume = COALESCE(volume, 0.0),
  selected_fish = COALESCE(fish_selections, '{}'::jsonb),
  feed_types = COALESCE(available_feeds, '{}'::jsonb),
  available_feed_qty = COALESCE(available_feeds, '{}'::jsonb),
  fish_feeding_data = COALESCE(feed_portion_data, '{}'::jsonb),
  feed_duration_data = COALESCE(feed_duration_data, '{}'::jsonb),
  tank_size_notice = COALESCE(tank_shape_warnings, '{}'::jsonb)
WHERE 
  tank_name IS NULL OR 
  calculated_volume IS NULL OR 
  selected_fish IS NULL OR 
  feed_types IS NULL OR 
  available_feed_qty IS NULL OR 
  fish_feeding_data IS NULL OR 
  feed_duration_data IS NULL OR 
  tank_size_notice IS NULL;

-- Set NOT NULL constraints after data migration
ALTER TABLE tanks ALTER COLUMN tank_name SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN calculated_volume SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN selected_fish SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_types SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN available_feed_qty SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN fish_feeding_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_duration_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN tank_size_notice SET NOT NULL;

-- Add check constraints
ALTER TABLE tanks ADD CONSTRAINT IF NOT EXISTS check_tank_shape 
  CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder'));

ALTER TABLE tanks ADD CONSTRAINT IF NOT EXISTS check_unit 
  CHECK (unit IN ('CM', 'IN'));

ALTER TABLE tanks ADD CONSTRAINT IF NOT EXISTS check_volume_positive 
  CHECK (calculated_volume > 0);

ALTER TABLE tanks ADD CONSTRAINT IF NOT EXISTS check_dimensions_positive 
  CHECK (length > 0 AND width > 0 AND height > 0);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tanks_tank_name ON tanks(tank_name);
CREATE INDEX IF NOT EXISTS idx_tanks_calculated_volume ON tanks(calculated_volume);
CREATE INDEX IF NOT EXISTS idx_tanks_selected_fish ON tanks USING GIN (selected_fish);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_types ON tanks USING GIN (feed_types);
CREATE INDEX IF NOT EXISTS idx_tanks_available_feed_qty ON tanks USING GIN (available_feed_qty);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_feeding_data ON tanks USING GIN (fish_feeding_data);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_duration_data ON tanks USING GIN (feed_duration_data);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_size_notice ON tanks USING GIN (tank_size_notice);

-- Add comments
COMMENT ON COLUMN tanks.tank_name IS 'Name of the tank';
COMMENT ON COLUMN tanks.calculated_volume IS 'Calculated volume in liters';
COMMENT ON COLUMN tanks.selected_fish IS 'Fish species and quantities selected for the tank';
COMMENT ON COLUMN tanks.feed_types IS 'Types of feed and their quantities in grams';
COMMENT ON COLUMN tanks.available_feed_qty IS 'Available quantity of each feed type in grams';
COMMENT ON COLUMN tanks.fish_feeding_data IS 'Feeding data per fish including portion size, frequency, and preferences';
COMMENT ON COLUMN tanks.feed_duration_data IS 'Calculated duration data for each feed type';
COMMENT ON COLUMN tanks.tank_size_notice IS 'Tank size warnings and notices for selected fish';

-- Optional: Drop old columns that are no longer needed
-- Uncomment these lines if you want to remove the old columns
-- ALTER TABLE tanks DROP COLUMN IF EXISTS name;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS volume;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS fish_selections;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS available_feeds;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS feed_portion_data;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS tank_shape_warnings;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS feeding_recommendations;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS recommended_fish_quantities;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS feed_inventory;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS incompatible_feeds;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS fish_details;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS feed_recommendations;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS current_step;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS form_validation_status;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS calculation_metadata;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS ui_state;
-- ALTER TABLE tanks DROP COLUMN IF EXISTS created_at;

-- Verify the updated schema
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'tanks' 
ORDER BY ordinal_position;
