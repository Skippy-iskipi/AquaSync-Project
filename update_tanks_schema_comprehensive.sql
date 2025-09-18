-- Comprehensive update to tanks table schema
-- This migration adds all missing columns for the enhanced tank management system

-- Add feed duration data column (calculated feed consumption and duration)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_duration_data JSONB DEFAULT '{}';

-- Add incompatible feeds data column (feed compatibility analysis)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS incompatible_feeds JSONB DEFAULT '{}';

-- Add fish details data column (detailed fish information for summary)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS fish_details JSONB DEFAULT '{}';

-- Add tank shape warnings column (compatibility warnings for tank shapes)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS tank_shape_warnings JSONB DEFAULT '{}';

-- Add feed recommendations column (AI-generated feed recommendations)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_recommendations JSONB DEFAULT '{}';

-- Add step tracking column (current step in tank creation process)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS current_step INTEGER DEFAULT 0;

-- Add form validation status column
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS form_validation_status JSONB DEFAULT '{}';

-- Add calculation metadata column (volume calculation steps, etc.)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS calculation_metadata JSONB DEFAULT '{}';

-- Add UI state column (for preserving UI state during editing)
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS ui_state JSONB DEFAULT '{}';

-- Add comments for documentation
COMMENT ON COLUMN tanks.feed_duration_data IS 'Calculated feed consumption data including daily consumption, days remaining, and fish-specific consumption breakdown';
COMMENT ON COLUMN tanks.incompatible_feeds IS 'Feed compatibility analysis showing which feeds are incompatible with which fish species';
COMMENT ON COLUMN tanks.fish_details IS 'Detailed fish information including portion_grams, feeding_frequency, preferred_food, max_size, temperament, water_type';
COMMENT ON COLUMN tanks.tank_shape_warnings IS 'Compatibility warnings for fish species with specific tank shapes (bowl, cylinder, rectangle)';
COMMENT ON COLUMN tanks.feed_recommendations IS 'AI-generated feed recommendations based on fish species dietary preferences';
COMMENT ON COLUMN tanks.current_step IS 'Current step in the tank creation/editing process (0=Tank Setup, 1=Fish Selection, 2=Feed Inventory, 3=Summary)';
COMMENT ON COLUMN tanks.form_validation_status IS 'Form validation status for each step of the tank creation process';
COMMENT ON COLUMN tanks.calculation_metadata IS 'Metadata for calculations including volume calculation steps, feed duration calculations, etc.';
COMMENT ON COLUMN tanks.ui_state IS 'UI state preservation for form fields, controllers, and temporary data during editing';

-- Create indexes for better performance on new JSONB columns
CREATE INDEX IF NOT EXISTS idx_tanks_feed_duration_data ON tanks USING GIN (feed_duration_data);
CREATE INDEX IF NOT EXISTS idx_tanks_incompatible_feeds ON tanks USING GIN (incompatible_feeds);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_details ON tanks USING GIN (fish_details);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_shape_warnings ON tanks USING GIN (tank_shape_warnings);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_recommendations ON tanks USING GIN (feed_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_form_validation_status ON tanks USING GIN (form_validation_status);
CREATE INDEX IF NOT EXISTS idx_tanks_calculation_metadata ON tanks USING GIN (calculation_metadata);
CREATE INDEX IF NOT EXISTS idx_tanks_ui_state ON tanks USING GIN (ui_state);

-- Create index on current_step for filtering
CREATE INDEX IF NOT EXISTS idx_tanks_current_step ON tanks (current_step);

-- Update existing columns with better constraints and defaults
ALTER TABLE tanks ALTER COLUMN fish_selections SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN compatibility_results SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN feeding_recommendations SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN recommended_fish_quantities SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN available_feeds SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN feed_inventory SET DEFAULT '{}';
ALTER TABLE tanks ALTER COLUMN feed_portion_data SET DEFAULT '{}';

-- Add check constraints for data validation
ALTER TABLE tanks ADD CONSTRAINT check_tank_shape 
  CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder'));

ALTER TABLE tanks ADD CONSTRAINT check_unit 
  CHECK (unit IN ('CM', 'IN'));

ALTER TABLE tanks ADD CONSTRAINT check_volume_positive 
  CHECK (volume > 0);

ALTER TABLE tanks ADD CONSTRAINT check_dimensions_positive 
  CHECK (length > 0 AND width > 0 AND height > 0);

ALTER TABLE tanks ADD CONSTRAINT check_current_step_range 
  CHECK (current_step >= 0 AND current_step <= 3);

-- Create a function to validate JSONB structure for fish_selections
CREATE OR REPLACE FUNCTION validate_fish_selections(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if all values are positive integers
  RETURN (
    SELECT bool_and(
      jsonb_typeof(value) = 'number' AND 
      (value #>> '{}')::integer > 0
    )
    FROM jsonb_each(data)
  );
END;
$$ LANGUAGE plpgsql;

-- Create a function to validate JSONB structure for available_feeds
CREATE OR REPLACE FUNCTION validate_available_feeds(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if all values are positive numbers
  RETURN (
    SELECT bool_and(
      jsonb_typeof(value) = 'number' AND 
      (value #>> '{}')::numeric > 0
    )
    FROM jsonb_each(data)
  );
END;
$$ LANGUAGE plpgsql;

-- Add check constraints using the validation functions
ALTER TABLE tanks ADD CONSTRAINT check_fish_selections_valid 
  CHECK (validate_fish_selections(fish_selections));

ALTER TABLE tanks ADD CONSTRAINT check_available_feeds_valid 
  CHECK (validate_available_feeds(available_feeds));

-- Create a view for easier querying of tank data
CREATE OR REPLACE VIEW tank_summary AS
SELECT 
  id,
  name,
  tank_shape,
  length,
  width,
  height,
  unit,
  volume,
  jsonb_object_keys(fish_selections) as fish_species,
  jsonb_object_keys(available_feeds) as feed_types,
  current_step,
  date_created,
  last_updated,
  -- Calculate total fish count
  (
    SELECT SUM((value #>> '{}')::integer)
    FROM jsonb_each(fish_selections)
  ) as total_fish_count,
  -- Calculate total feed amount
  (
    SELECT SUM((value #>> '{}')::numeric)
    FROM jsonb_each(available_feeds)
  ) as total_feed_amount
FROM tanks;

-- Create a function to get tank statistics
CREATE OR REPLACE FUNCTION get_tank_stats(tank_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'fish_count', (
      SELECT SUM((value #>> '{}')::integer)
      FROM jsonb_each(fish_selections)
    ),
    'fish_species_count', jsonb_array_length(jsonb_object_keys(fish_selections)),
    'feed_types_count', jsonb_array_length(jsonb_object_keys(available_feeds)),
    'total_feed_amount', (
      SELECT SUM((value #>> '{}')::numeric)
      FROM jsonb_each(available_feeds)
    ),
    'has_compatibility_issues', (
      CASE 
        WHEN compatibility_results ? 'has_incompatible_pairs' 
        THEN (compatibility_results ->> 'has_incompatible_pairs')::boolean
        ELSE false
      END
    ),
    'completion_percentage', (
      CASE 
        WHEN current_step = 0 THEN 25
        WHEN current_step = 1 THEN 50
        WHEN current_step = 2 THEN 75
        WHEN current_step = 3 THEN 100
        ELSE 0
      END
    )
  )
  INTO result
  FROM tanks
  WHERE id = tank_id;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON tanks TO authenticated;
GRANT SELECT ON tank_summary TO authenticated;
GRANT EXECUTE ON FUNCTION get_tank_stats(UUID) TO authenticated;

-- Create a trigger to update last_updated timestamp
CREATE OR REPLACE FUNCTION update_tanks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists and create new one
DROP TRIGGER IF EXISTS update_tanks_updated_at_trigger ON tanks;
CREATE TRIGGER update_tanks_updated_at_trigger
  BEFORE UPDATE ON tanks
  FOR EACH ROW
  EXECUTE FUNCTION update_tanks_updated_at();

-- Insert sample data for testing (optional)
-- INSERT INTO tanks (
--   name, tank_shape, length, width, height, unit, volume,
--   fish_selections, available_feeds, current_step
-- ) VALUES (
--   'Test Tank', 'rectangle', 60, 30, 40, 'CM', 72.0,
--   '{"Goldfish": 2, "Koi": 1}'::jsonb,
--   '{"Pellets": 500.0, "Flakes": 300.0}'::jsonb,
--   3
-- );
