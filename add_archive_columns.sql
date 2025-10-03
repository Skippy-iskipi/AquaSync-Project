-- Add archive columns to all tables that support archiving functionality
-- This migration adds 'archived' and 'archived_at' columns to track archived records

-- 1. Fish Predictions table
ALTER TABLE fish_predictions 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 2. Water Calculations table
ALTER TABLE water_calculations 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 3. Fish Calculations table
ALTER TABLE fish_calculations 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 4. Compatibility Results table
ALTER TABLE compatibility_results 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 5. Diet Calculations table
ALTER TABLE diet_calculations 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 6. Fish Volume Calculations table
ALTER TABLE fish_volume_calculations 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- 7. Tanks table
ALTER TABLE tanks 
ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

-- Create indexes for better query performance when filtering archived records
CREATE INDEX IF NOT EXISTS idx_fish_predictions_archived ON fish_predictions(archived);
CREATE INDEX IF NOT EXISTS idx_water_calculations_archived ON water_calculations(archived);
CREATE INDEX IF NOT EXISTS idx_fish_calculations_archived ON fish_calculations(archived);
CREATE INDEX IF NOT EXISTS idx_compatibility_results_archived ON compatibility_results(archived);
CREATE INDEX IF NOT EXISTS idx_diet_calculations_archived ON diet_calculations(archived);
CREATE INDEX IF NOT EXISTS idx_fish_volume_calculations_archived ON fish_volume_calculations(archived);
CREATE INDEX IF NOT EXISTS idx_tanks_archived ON tanks(archived);

-- Add comments to document the purpose of these columns
COMMENT ON COLUMN fish_predictions.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN fish_predictions.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN water_calculations.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN water_calculations.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN fish_calculations.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN fish_calculations.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN compatibility_results.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN compatibility_results.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN diet_calculations.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN diet_calculations.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN fish_volume_calculations.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN fish_volume_calculations.archived_at IS 'Timestamp when the record was archived';

COMMENT ON COLUMN tanks.archived IS 'Indicates if the record has been archived (soft deleted)';
COMMENT ON COLUMN tanks.archived_at IS 'Timestamp when the record was archived';
