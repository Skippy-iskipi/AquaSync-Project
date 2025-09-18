-- Complete Tank Table Structure
-- This includes all necessary columns for the tank management system

-- Drop existing table if you want to start fresh (optional)
-- DROP TABLE IF EXISTS tanks CASCADE;

-- Create the complete tanks table
CREATE TABLE IF NOT EXISTS tanks (
  -- Primary key and user reference
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Basic tank information
  name TEXT NOT NULL,
  tank_shape TEXT NOT NULL CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder')),
  length DECIMAL(10,2) NOT NULL CHECK (length > 0),
  width DECIMAL(10,2) NOT NULL CHECK (width > 0),
  height DECIMAL(10,2) NOT NULL CHECK (height > 0),
  unit TEXT NOT NULL CHECK (unit IN ('CM', 'IN')),
  volume DECIMAL(10,2) NOT NULL CHECK (volume > 0),
  
  -- Fish selection and data
  fish_selections JSONB NOT NULL DEFAULT '{}',
  compatibility_results JSONB NOT NULL DEFAULT '{}',
  
  -- Feeding and feed data
  feeding_recommendations JSONB NOT NULL DEFAULT '{}',
  recommended_fish_quantities JSONB NOT NULL DEFAULT '{}',
  available_feeds JSONB NOT NULL DEFAULT '{}',
  feed_inventory JSONB NOT NULL DEFAULT '{}',
  feed_portion_data JSONB NOT NULL DEFAULT '{}',
  
  -- Timestamps
  date_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);
CREATE INDEX IF NOT EXISTS idx_tanks_created_at ON tanks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_selections ON tanks USING GIN (fish_selections);
CREATE INDEX IF NOT EXISTS idx_tanks_compatibility_results ON tanks USING GIN (compatibility_results);
CREATE INDEX IF NOT EXISTS idx_tanks_feeding_recommendations ON tanks USING GIN (feeding_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_recommended_fish_quantities ON tanks USING GIN (recommended_fish_quantities);
CREATE INDEX IF NOT EXISTS idx_tanks_available_feeds ON tanks USING GIN (available_feeds);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_inventory ON tanks USING GIN (feed_inventory);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_portion_data ON tanks USING GIN (feed_portion_data);

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
COMMENT ON COLUMN tanks.id IS 'Primary key UUID';
COMMENT ON COLUMN tanks.user_id IS 'Foreign key to auth.users table';
COMMENT ON COLUMN tanks.name IS 'Name of the tank';
COMMENT ON COLUMN tanks.tank_shape IS 'Shape of the tank: rectangle, bowl, or cylinder';
COMMENT ON COLUMN tanks.length IS 'Length of the tank';
COMMENT ON COLUMN tanks.width IS 'Width of the tank';
COMMENT ON COLUMN tanks.height IS 'Height of the tank';
COMMENT ON COLUMN tanks.unit IS 'Unit of measurement: CM or IN';
COMMENT ON COLUMN tanks.volume IS 'Calculated volume in liters';
COMMENT ON COLUMN tanks.fish_selections IS 'Fish species and quantities selected for the tank';
COMMENT ON COLUMN tanks.compatibility_results IS 'Fish compatibility analysis results';
COMMENT ON COLUMN tanks.feeding_recommendations IS 'AI-generated feeding recommendations';
COMMENT ON COLUMN tanks.recommended_fish_quantities IS 'AI-recommended fish quantities per species';
COMMENT ON COLUMN tanks.available_feeds IS 'Available feed types and quantities in grams';
COMMENT ON COLUMN tanks.feed_inventory IS 'Detailed feed inventory information';
COMMENT ON COLUMN tanks.feed_portion_data IS 'Portion data per fish species';
COMMENT ON COLUMN tanks.date_created IS 'Creation timestamp';
COMMENT ON COLUMN tanks.last_updated IS 'Last update timestamp';
COMMENT ON COLUMN tanks.created_at IS 'Creation timestamp (legacy)';

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON tanks TO authenticated;
