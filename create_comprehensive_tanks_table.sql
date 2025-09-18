-- Comprehensive Tanks Table with All Required Columns
-- This table stores complete tank management data including fish, feeds, and analysis

CREATE TABLE IF NOT EXISTS tanks (
  -- Primary key and user reference
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Basic tank information
  tank_name TEXT NOT NULL,
  tank_shape TEXT NOT NULL CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder')),
  
  -- Tank dimensions
  length DECIMAL(10,2) NOT NULL CHECK (length > 0),
  width DECIMAL(10,2) NOT NULL CHECK (width > 0),
  height DECIMAL(10,2) NOT NULL CHECK (height > 0),
  unit TEXT NOT NULL CHECK (unit IN ('CM', 'IN')),
  tank_volume DECIMAL(10,2) NOT NULL CHECK (tank_volume > 0),
  
  -- Selected fish data with feeding information
  selected_fish JSONB NOT NULL DEFAULT '{}',
  -- Structure: {"Goldfish": 2, "Koi": 1}
  
  fish_feeding_data JSONB NOT NULL DEFAULT '{}',
  -- Structure: {
  --   "Goldfish": {
  --     "portion_per_feeding": 5.0,
  --     "feeding_frequency": 2,
  --     "preferred_food": "pellets, flakes",
  --     "daily_consumption": 10.0
  --   }
  -- }
  
  -- Feed inventory data
  feed_inventory JSONB NOT NULL DEFAULT '{}',
  -- Structure: {
  --   "Pellets": {
  --     "quantity_grams": 500.0,
  --     "daily_consumption": 16.67,
  --     "days_remaining": 30,
  --     "is_low_stock": false,
  --     "is_critical": false,
  --     "consumption_by_fish": {
  --       "Goldfish": 10.0,
  --       "Koi": 6.67
  --     }
  --   }
  -- }
  
  -- Compatibility analysis
  compatibility_analysis JSONB NOT NULL DEFAULT '{}',
  -- Structure: {
  --   "has_incompatible_pairs": false,
  --   "has_conditional_pairs": true,
  --   "incompatible_pairs": [],
  --   "conditional_pairs": [
  --     {
  --       "pair": ["Goldfish", "Koi"],
  --       "reasons": ["Similar dietary requirements"],
  --       "type": "conditional"
  --     }
  --   ],
  --   "tank_size_warnings": {
  --     "Goldfish": "Goldfish is suitable for this tank size.",
  --     "Koi": "Koi needs more swimming space than this tank provides."
  --   }
  -- }
  
  -- Additional analysis data
  feeding_recommendations JSONB NOT NULL DEFAULT '{}',
  -- Structure: {
  --   "feeding_schedule": "2 times daily",
  --   "portion_per_feeding": "5g per fish",
  --   "feeding_notes": "Feed in morning and evening",
  --   "total_daily_food": "30g"
  -- }
  
  feed_recommendations JSONB NOT NULL DEFAULT '{}',
  -- Structure: {
  --   "recommended": ["Pellets", "Flakes", "Spirulina"],
  --   "incompatible": ["Bloodworms", "Live Food"],
  --   "reasoning": {
  --     "Pellets": "Suitable for omnivorous fish",
  --     "Bloodworms": "Not suitable for herbivorous fish"
  --   }
  -- }
  
  -- Timestamps
  date_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);
CREATE INDEX IF NOT EXISTS idx_tanks_created_at ON tanks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_name ON tanks(tank_name);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_shape ON tanks(tank_shape);
CREATE INDEX IF NOT EXISTS idx_tanks_tank_volume ON tanks(tank_volume);

-- JSONB indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_tanks_selected_fish ON tanks USING GIN (selected_fish);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_feeding_data ON tanks USING GIN (fish_feeding_data);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_inventory ON tanks USING GIN (feed_inventory);
CREATE INDEX IF NOT EXISTS idx_tanks_compatibility_analysis ON tanks USING GIN (compatibility_analysis);
CREATE INDEX IF NOT EXISTS idx_tanks_feeding_recommendations ON tanks USING GIN (feeding_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_recommendations ON tanks USING GIN (feed_recommendations);

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
COMMENT ON TABLE tanks IS 'Comprehensive tank management data including fish selections, feed inventory, and compatibility analysis';
COMMENT ON COLUMN tanks.id IS 'Primary key UUID';
COMMENT ON COLUMN tanks.user_id IS 'Foreign key to auth.users table';
COMMENT ON COLUMN tanks.tank_name IS 'Name of the tank';
COMMENT ON COLUMN tanks.tank_shape IS 'Shape of the tank: rectangle, bowl, or cylinder';
COMMENT ON COLUMN tanks.length IS 'Length of the tank';
COMMENT ON COLUMN tanks.width IS 'Width of the tank';
COMMENT ON COLUMN tanks.height IS 'Height of the tank';
COMMENT ON COLUMN tanks.unit IS 'Unit of measurement: CM or IN';
COMMENT ON COLUMN tanks.tank_volume IS 'Calculated volume in liters';
COMMENT ON COLUMN tanks.selected_fish IS 'Fish species and quantities selected for the tank';
COMMENT ON COLUMN tanks.fish_feeding_data IS 'Detailed feeding data per fish including portion size, frequency, and preferences';
COMMENT ON COLUMN tanks.feed_inventory IS 'Feed inventory with consumption calculations and duration estimates';
COMMENT ON COLUMN tanks.compatibility_analysis IS 'Comprehensive compatibility analysis including fish pairs and tank size warnings';
COMMENT ON COLUMN tanks.feeding_recommendations IS 'AI-generated feeding recommendations and schedules';
COMMENT ON COLUMN tanks.feed_recommendations IS 'Feed type recommendations based on fish dietary preferences';
COMMENT ON COLUMN tanks.date_created IS 'Creation timestamp';
COMMENT ON COLUMN tanks.last_updated IS 'Last update timestamp';
COMMENT ON COLUMN tanks.created_at IS 'Creation timestamp (legacy)';

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
  tank_volume,
  selected_fish,
  fish_feeding_data,
  feed_inventory,
  compatibility_analysis,
  feeding_recommendations,
  feed_recommendations,
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
    FROM jsonb_each(feed_inventory)
  ) as total_feed_amount
FROM tanks;

-- Create helper functions for common queries
CREATE OR REPLACE FUNCTION get_tank_fish_count(tank_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT SUM((value #>> '{}')::integer)
    FROM tanks, jsonb_each(selected_fish)
    WHERE id = tank_id
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_tank_feed_duration(tank_id UUID, feed_name TEXT)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT (feed_inventory -> feed_name ->> 'days_remaining')::integer
    FROM tanks
    WHERE id = tank_id
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_tank_compatibility_status(tank_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN (
    SELECT CASE 
      WHEN (compatibility_analysis ->> 'has_incompatible_pairs')::boolean THEN 'Incompatible'
      WHEN (compatibility_analysis ->> 'has_conditional_pairs')::boolean THEN 'Conditional'
      ELSE 'Compatible'
    END
    FROM tanks
    WHERE id = tank_id
  );
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON tanks TO authenticated;
GRANT SELECT ON tank_summary TO authenticated;
GRANT EXECUTE ON FUNCTION get_tank_fish_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tank_feed_duration(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tank_compatibility_status(UUID) TO authenticated;
