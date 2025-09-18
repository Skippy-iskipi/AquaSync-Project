-- Simplified tanks table schema with only essential data
-- This includes only the data that's actually saved from add_edit_tank.dart

-- Drop existing table if you want to start fresh (optional)
-- DROP TABLE IF EXISTS tanks CASCADE;

-- Create the simplified tanks table
CREATE TABLE IF NOT EXISTS tanks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Basic tank information
  tank_name TEXT NOT NULL,
  tank_shape TEXT NOT NULL CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder')),
  length DECIMAL(10,2) NOT NULL CHECK (length > 0),
  width DECIMAL(10,2) NOT NULL CHECK (width > 0),
  height DECIMAL(10,2) NOT NULL CHECK (height > 0),
  unit TEXT NOT NULL CHECK (unit IN ('CM', 'IN')),
  calculated_volume DECIMAL(10,2) NOT NULL CHECK (calculated_volume > 0),
  
  -- Selected fish data
  selected_fish JSONB NOT NULL DEFAULT '{}', -- {"Goldfish": 2, "Koi": 1}
  
  -- Feed data
  feed_types JSONB NOT NULL DEFAULT '{}', -- {"Pellets": 500.0, "Flakes": 300.0}
  available_feed_qty JSONB NOT NULL DEFAULT '{}', -- Same as feed_types but for clarity
  
  -- Fish feeding data
  fish_feeding_data JSONB NOT NULL DEFAULT '{}', -- Per fish feeding information
  -- Structure: {"Goldfish": {"portion_per_feeding": 5.0, "feeding_frequency": 2, "daily_consumption": 10.0, "preferred_food": "pellets, flakes"}}
  
  -- Feed duration calculations
  feed_duration_data JSONB NOT NULL DEFAULT '{}', -- Days remaining for each feed
  -- Structure: {"Pellets": {"days_remaining": 30, "daily_consumption": 16.67, "is_low_stock": false}}
  
  -- Compatibility and warnings
  compatibility_results JSONB NOT NULL DEFAULT '{}', -- Fish compatibility analysis
  tank_size_notice JSONB NOT NULL DEFAULT '{}', -- Tank size warnings for fish
  
  -- Timestamps
  date_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);
CREATE INDEX IF NOT EXISTS idx_tanks_created_at ON tanks(date_created DESC);
CREATE INDEX IF NOT EXISTS idx_tanks_selected_fish ON tanks USING GIN (selected_fish);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_types ON tanks USING GIN (feed_types);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_feeding_data ON tanks USING GIN (fish_feeding_data);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_duration_data ON tanks USING GIN (feed_duration_data);
CREATE INDEX IF NOT EXISTS idx_tanks_compatibility_results ON tanks USING GIN (compatibility_results);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_size_notice ON tanks USING GIN (tank_size_notice);

-- Enable Row Level Security
ALTER TABLE tanks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own tanks" ON tanks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tanks" ON tanks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tanks" ON tanks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tanks" ON tanks
  FOR DELETE USING (auth.uid() = user_id);

-- Create function to automatically update last_updated timestamp
CREATE OR REPLACE FUNCTION update_tanks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update last_updated
CREATE TRIGGER update_tanks_updated_at_trigger
  BEFORE UPDATE ON tanks
  FOR EACH ROW
  EXECUTE FUNCTION update_tanks_updated_at();

-- Add comments for documentation
COMMENT ON TABLE tanks IS 'Tank management data with fish selections, feed inventory, and compatibility analysis';
COMMENT ON COLUMN tanks.tank_name IS 'Name of the tank';
COMMENT ON COLUMN tanks.tank_shape IS 'Shape of the tank: rectangle, bowl, or cylinder';
COMMENT ON COLUMN tanks.length IS 'Length of the tank';
COMMENT ON COLUMN tanks.width IS 'Width of the tank';
COMMENT ON COLUMN tanks.height IS 'Height of the tank';
COMMENT ON COLUMN tanks.unit IS 'Unit of measurement: CM or IN';
COMMENT ON COLUMN tanks.calculated_volume IS 'Calculated volume in liters';
COMMENT ON COLUMN tanks.selected_fish IS 'Fish species and quantities selected for the tank';
COMMENT ON COLUMN tanks.feed_types IS 'Types of feed and their quantities in grams';
COMMENT ON COLUMN tanks.available_feed_qty IS 'Available quantity of each feed type in grams';
COMMENT ON COLUMN tanks.fish_feeding_data IS 'Feeding data per fish including portion size, frequency, and preferences';
COMMENT ON COLUMN tanks.feed_duration_data IS 'Calculated duration data for each feed type';
COMMENT ON COLUMN tanks.compatibility_results IS 'Fish compatibility analysis results';
COMMENT ON COLUMN tanks.tank_size_notice IS 'Tank size warnings and notices for selected fish';

-- Create a view for easier querying
CREATE OR REPLACE VIEW tank_summary AS
SELECT 
  id,
  tank_name,
  tank_shape,
  length,
  width,
  height,
  unit,
  calculated_volume,
  selected_fish,
  feed_types,
  fish_feeding_data,
  feed_duration_data,
  compatibility_results,
  tank_size_notice,
  date_created,
  last_updated,
  -- Calculate total fish count
  (
    SELECT SUM((value #>> '{}')::integer)
    FROM jsonb_each(selected_fish)
  ) as total_fish_count,
  -- Calculate total feed amount
  (
    SELECT SUM((value #>> '{}')::numeric)
    FROM jsonb_each(feed_types)
  ) as total_feed_amount
FROM tanks;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON tanks TO authenticated;
GRANT SELECT ON tank_summary TO authenticated;
