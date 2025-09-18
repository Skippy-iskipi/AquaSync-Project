-- Add missing columns to tanks table for enhanced tank management features
-- This migration adds all the new columns needed for the tank management system

-- Add recommended fish quantities column
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS recommended_fish_quantities JSONB;

-- Add feed portion data column
ALTER TABLE tanks ADD COLUMN IF NOT EXISTS feed_portion_data JSONB;

-- Add comments for documentation
COMMENT ON COLUMN tanks.recommended_fish_quantities IS 'AI-calculated recommended fish quantities per species based on tank volume and compatibility';
COMMENT ON COLUMN tanks.feed_portion_data IS 'Detailed feeding portion data per fish species including frequency, portion sizes, and feeding times';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tanks_recommended_fish_quantities ON tanks USING GIN (recommended_fish_quantities);
CREATE INDEX IF NOT EXISTS idx_tanks_feed_portion_data ON tanks USING GIN (feed_portion_data);
