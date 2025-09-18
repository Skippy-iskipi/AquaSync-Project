-- Complete fix for tank database schema
-- This script ensures all required columns exist and are properly configured

-- First, check if the tanks table exists, if not create it
CREATE TABLE IF NOT EXISTS tanks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  tank_shape TEXT NOT NULL DEFAULT 'rectangle',
  length DECIMAL(10,2) NOT NULL DEFAULT 0,
  width DECIMAL(10,2) NOT NULL DEFAULT 0,
  height DECIMAL(10,2) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'CM',
  volume DECIMAL(10,2) NOT NULL DEFAULT 0,
  fish_selections JSONB DEFAULT '{}',
  compatibility_results JSONB DEFAULT '{}',
  feeding_recommendations JSONB DEFAULT '{}',
  recommended_fish_quantities JSONB DEFAULT '{}',
  available_feeds JSONB DEFAULT '{}',
  feed_inventory JSONB DEFAULT '{}',
  feed_portion_data JSONB DEFAULT '{}',
  date_created TIMESTAMPTZ DEFAULT NOW(),
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if they don't exist
DO $$ 
BEGIN
  -- Add available_feeds column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'available_feeds') THEN
    ALTER TABLE tanks ADD COLUMN available_feeds JSONB DEFAULT '{}';
  END IF;
  
  -- Add feed_inventory column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'feed_inventory') THEN
    ALTER TABLE tanks ADD COLUMN feed_inventory JSONB DEFAULT '{}';
  END IF;
  
  -- Add feed_portion_data column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'feed_portion_data') THEN
    ALTER TABLE tanks ADD COLUMN feed_portion_data JSONB DEFAULT '{}';
  END IF;
  
  -- Add feeding_recommendations column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'feeding_recommendations') THEN
    ALTER TABLE tanks ADD COLUMN feeding_recommendations JSONB DEFAULT '{}';
  END IF;
  
  -- Add recommended_fish_quantities column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'recommended_fish_quantities') THEN
    ALTER TABLE tanks ADD COLUMN recommended_fish_quantities JSONB DEFAULT '{}';
  END IF;
  
  -- Add compatibility_results column if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tanks' AND column_name = 'compatibility_results') THEN
    ALTER TABLE tanks ADD COLUMN compatibility_results JSONB DEFAULT '{}';
  END IF;
END $$;

-- Update existing NULL values to empty JSONB objects
UPDATE tanks SET 
  available_feeds = COALESCE(available_feeds, '{}'::jsonb),
  feed_inventory = COALESCE(feed_inventory, '{}'::jsonb),
  feed_portion_data = COALESCE(feed_portion_data, '{}'::jsonb),
  feeding_recommendations = COALESCE(feeding_recommendations, '{}'::jsonb),
  recommended_fish_quantities = COALESCE(recommended_fish_quantities, '{}'::jsonb),
  compatibility_results = COALESCE(compatibility_results, '{}'::jsonb)
WHERE 
  available_feeds IS NULL OR 
  feed_inventory IS NULL OR 
  feed_portion_data IS NULL OR 
  feeding_recommendations IS NULL OR 
  recommended_fish_quantities IS NULL OR 
  compatibility_results IS NULL;

-- Set NOT NULL constraints after updating existing data
ALTER TABLE tanks ALTER COLUMN available_feeds SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_inventory SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_portion_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feeding_recommendations SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN recommended_fish_quantities SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN compatibility_results SET NOT NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);
CREATE INDEX IF NOT EXISTS idx_tanks_available_feeds ON tanks USING GIN (available_feeds);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_inventory ON tanks USING GIN (feed_inventory);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_portion_data ON tanks USING GIN (feed_portion_data);
CREATE INDEX IF NOT EXISTS idx_tanks_feeding_recommendations ON tanks USING GIN (feeding_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_recommended_fish_quantities ON tanks USING GIN (recommended_fish_quantities);
CREATE INDEX IF NOT EXISTS idx_tanks_compatibility_results ON tanks USING GIN (compatibility_results);
CREATE INDEX IF NOT EXISTS idx_tanks_fish_selections ON tanks USING GIN (fish_selections);

-- Add comments for documentation
COMMENT ON TABLE tanks IS 'Stores user tank configurations with fish selections, feeding data, and compatibility analysis';
COMMENT ON COLUMN tanks.user_id IS 'Reference to the user who owns this tank';
COMMENT ON COLUMN tanks.name IS 'User-defined name for the tank';
COMMENT ON COLUMN tanks.tank_shape IS 'Shape of the tank: rectangle, bowl, or cylinder';
COMMENT ON COLUMN tanks.length IS 'Length dimension of the tank';
COMMENT ON COLUMN tanks.width IS 'Width dimension of the tank (not used for cylinder)';
COMMENT ON COLUMN tanks.height IS 'Height dimension of the tank';
COMMENT ON COLUMN tanks.unit IS 'Unit of measurement: CM or IN';
COMMENT ON COLUMN tanks.volume IS 'Calculated volume of the tank in liters';
COMMENT ON COLUMN tanks.fish_selections IS 'JSONB object mapping fish species to quantities';
COMMENT ON COLUMN tanks.compatibility_results IS 'Results of fish compatibility analysis';
COMMENT ON COLUMN tanks.feeding_recommendations IS 'AI-generated feeding recommendations';
COMMENT ON COLUMN tanks.recommended_fish_quantities IS 'AI-recommended fish quantities per species';
COMMENT ON COLUMN tanks.available_feeds IS 'Available feed types and quantities in grams';
COMMENT ON COLUMN tanks.feed_inventory IS 'Detailed feed inventory information';
COMMENT ON COLUMN tanks.feed_portion_data IS 'Portion data per fish species';
COMMENT ON COLUMN tanks.date_created IS 'When the tank was first created';
COMMENT ON COLUMN tanks.last_updated IS 'When the tank was last modified';
COMMENT ON COLUMN tanks.created_at IS 'Database record creation timestamp';

-- Enable Row Level Security (RLS)
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

-- Verify the table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'tanks' 
ORDER BY ordinal_position;
