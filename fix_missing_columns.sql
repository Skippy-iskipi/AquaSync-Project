-- Fix missing columns error by adding all columns that the Tank model expects
-- This will resolve the PostgrestException: Could not find the 'available_feeds' column

-- Add all missing columns that the Tank model is trying to use
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS available_feeds JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_inventory JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_portion_data JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feeding_recommendations JSONB DEFAULT '{}';
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS recommended_fish_quantities JSONB DEFAULT '{}';

-- Update existing NULL values to empty JSONB objects
UPDATE tanks SET 
  available_feeds = COALESCE(available_feeds, '{}'::jsonb),
  feed_inventory = COALESCE(feed_inventory, '{}'::jsonb),
  feed_portion_data = COALESCE(feed_portion_data, '{}'::jsonb),
  feeding_recommendations = COALESCE(feeding_recommendations, '{}'::jsonb),
  recommended_fish_quantities = COALESCE(recommended_fish_quantities, '{}'::jsonb)
WHERE 
  available_feeds IS NULL OR 
  feed_inventory IS NULL OR 
  feed_portion_data IS NULL OR 
  feeding_recommendations IS NULL OR 
  recommended_fish_quantities IS NULL;

-- Set NOT NULL constraints after updating existing data
ALTER TABLE tanks ALTER COLUMN available_feeds SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_inventory SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feed_portion_data SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN feeding_recommendations SET NOT NULL;
ALTER TABLE tanks ALTER COLUMN recommended_fish_quantities SET NOT NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tanks_available_feeds ON tanks USING GIN (available_feeds);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_inventory ON tanks USING GIN (feed_inventory);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_portion_data ON tanks USING GIN (feed_portion_data);
CREATE INDEX IF NOT EXISTS idx_tanks_feeding_recommendations ON tanks USING GIN (feeding_recommendations);
CREATE INDEX IF NOT EXISTS idx_tanks_recommended_fish_quantities ON tanks USING GIN (recommended_fish_quantities);

-- Add comments for documentation
COMMENT ON COLUMN tanks.available_feeds IS 'Available feed types and quantities in grams';
COMMENT ON COLUMN tanks.feed_inventory IS 'Detailed feed inventory information';
COMMENT ON COLUMN tanks.feed_portion_data IS 'Portion data per fish species';
COMMENT ON COLUMN tanks.feeding_recommendations IS 'AI-generated feeding recommendations';
COMMENT ON COLUMN tanks.recommended_fish_quantities IS 'AI-recommended fish quantities per species';

-- Verify the columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'tanks' 
AND column_name IN ('available_feeds', 'feed_inventory', 'feed_portion_data', 'feeding_recommendations', 'recommended_fish_quantities')
ORDER BY column_name;
