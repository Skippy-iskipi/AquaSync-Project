-- Update Tank model to include all new fields from add_edit_tank.dart
-- This ensures the database schema matches the Flutter model

-- Add missing fields that are used in the UI but not stored in database
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_duration_data JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS incompatible_feeds JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS fish_details JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS tank_shape_warnings JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_recommendations JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS current_step INTEGER DEFAULT 0;
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS form_validation_status JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS calculation_metadata JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS ui_state JSONB DEFAULT '{}';

-- Update existing columns to match the Tank model exactly
-- Ensure all JSONB columns have proper defaults
UPDATE tanks SET 
  fish_selections = COALESCE(fish_selections, '{}'::jsonb),
  compatibility_results = COALESCE(compatibility_results, '{}'::jsonb),
  feeding_recommendations = COALESCE(feeding_recommendations, '{}'::jsonb),
  recommended_fish_quantities = COALESCE(recommended_fish_quantities, '{}'::jsonb),
  available_feeds = COALESCE(available_feeds, '{}'::jsonb),
  feed_inventory = COALESCE(feed_inventory, '{}'::jsonb),
  feed_portion_data = COALESCE(feed_portion_data, '{}'::jsonb),
  feed_duration_data = COALESCE(feed_duration_data, '{}'::jsonb),
  incompatible_feeds = COALESCE(incompatible_feeds, '{}'::jsonb),
  fish_details = COALESCE(fish_details, '{}'::jsonb),
  tank_shape_warnings = COALESCE(tank_shape_warnings, '{}'::jsonb),
  feed_recommendations = COALESCE(feed_recommendations, '{}'::jsonb),
  form_validation_status = COALESCE(form_validation_status, '{}'::jsonb),
  calculation_metadata = COALESCE(calculation_metadata, '{}'::jsonb),
  ui_state = COALESCE(ui_state, '{}'::jsonb)
WHERE 
  fish_selections IS NULL OR 
  compatibility_results IS NULL OR 
  feeding_recommendations IS NULL OR 
  recommended_fish_quantities IS NULL OR 
  available_feeds IS NULL OR 
  feed_inventory IS NULL OR 
  feed_portion_data IS NULL OR 
  feed_duration_data IS NULL OR 
  incompatible_feeds IS NULL OR 
  fish_details IS NULL OR 
  tank_shape_warnings IS NULL OR 
  feed_recommendations IS NULL OR 
  form_validation_status IS NULL OR 
  calculation_metadata IS NULL OR 
  ui_state IS NULL;

-- Set NOT NULL constraints after updating existing data
ALTER TABLE tanks ALTER COLUMN fish_selections SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN compatibility_results SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feeding_recommendations SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN recommended_fish_quantities SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN available_feeds SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_inventory SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_portion_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_duration_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN incompatible_feeds SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN fish_details SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN tank_shape_warnings SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_recommendations SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN current_step SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN form_validation_status SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN calculation_metadata SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN ui_state SET NOT NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tanks_feed_duration_data ON tanks USING GIN (feed_duration_data);
CREATE INDEX IF NOT EXISTS idx_tanks_incompatible_feeds ON tanks USING GIN (incompatible_feeds);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_details ON tanks USING GIN (fish_details);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_shape_warnings ON tanks USING GIN (tank_shape_warnings);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_recommendations ON tanks USING GIN (feed_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_form_validation_status ON tanks USING GIN (form_validation_status);
CREATE INDEX IF NOT EXISTS idx_tanks_calculation_metadata ON tanks USING GIN (calculation_metadata);
CREATE INDEX IF NOT EXISTS idx_tanks_ui_state ON tanks USING GIN (ui_state);
CREATE INDEX IF NOT EXISTS idx_tanks_current_step ON tanks (current_step);

-- Add comments for documentation
COMMENT ON COLUMN tanks.feed_duration_data IS 'Feed consumption calculations including daily consumption, days remaining, and fish-specific breakdown';
COMMENT ON COLUMN tanks.incompatible_feeds IS 'Feed compatibility analysis showing which feeds are incompatible with which fish';
COMMENT ON COLUMN tanks.fish_details IS 'Detailed fish information from fish_species table for summary display';
COMMENT ON COLUMN tanks.tank_shape_warnings IS 'Warnings for fish incompatible with specific tank shapes';
COMMENT ON COLUMN tanks.feed_recommendations IS 'AI-generated feed recommendations based on fish dietary preferences';
COMMENT ON COLUMN tanks.current_step IS 'Current step in tank creation process (0-3)';
COMMENT ON COLUMN tanks.form_validation_status IS 'Validation status for each form step';
COMMENT ON COLUMN tanks.calculation_metadata IS 'Metadata for volume and feed calculations';
COMMENT ON COLUMN tanks.ui_state IS 'UI state preservation during editing';

-- Verify the schema matches the Tank model
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'tanks' 
ORDER BY ordinal_position;
