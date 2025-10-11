-- Fix fish_tankmate_recommendations table schema
-- This script adds missing columns required by the population script

DO $$ 
BEGIN
    -- Add fish_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'fish_name'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN fish_name TEXT NOT NULL UNIQUE;
        RAISE NOTICE 'Added fish_name column';
    END IF;

    -- Add fully_compatible_tankmates column (TEXT array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'fully_compatible_tankmates'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN fully_compatible_tankmates TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Added fully_compatible_tankmates column';
    END IF;

    -- Add conditional_tankmates column (JSONB array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'conditional_tankmates'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN conditional_tankmates JSONB DEFAULT '[]'::jsonb;
        RAISE NOTICE 'Added conditional_tankmates column';
    END IF;

    -- Add incompatible_tankmates column (TEXT array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'incompatible_tankmates'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN incompatible_tankmates TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Added incompatible_tankmates column';
    END IF;

    -- Add special_requirements column (TEXT array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'special_requirements'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN special_requirements TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Added special_requirements column';
    END IF;

    -- Add care_level column (TEXT)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'care_level'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN care_level TEXT DEFAULT 'Intermediate';
        RAISE NOTICE 'Added care_level column';
    END IF;

    -- Add confidence_score column (DECIMAL)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'confidence_score'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN confidence_score DECIMAL(3,2) DEFAULT 0.0;
        RAISE NOTICE 'Added confidence_score column';
    END IF;

    -- Add total_fully_compatible column (INTEGER)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'total_fully_compatible'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN total_fully_compatible INTEGER DEFAULT 0;
        RAISE NOTICE 'Added total_fully_compatible column';
    END IF;

    -- Add total_conditional column (INTEGER)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'total_conditional'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN total_conditional INTEGER DEFAULT 0;
        RAISE NOTICE 'Added total_conditional column';
    END IF;

    -- Add total_incompatible column (INTEGER)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'total_incompatible'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN total_incompatible INTEGER DEFAULT 0;
        RAISE NOTICE 'Added total_incompatible column';
    END IF;

    -- Add total_recommended column (INTEGER)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_tankmate_recommendations' 
        AND column_name = 'total_recommended'
    ) THEN
        ALTER TABLE fish_tankmate_recommendations 
        ADD COLUMN total_recommended INTEGER DEFAULT 0;
        RAISE NOTICE 'Added total_recommended column';
    END IF;

END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_tankmate_fish_name ON fish_tankmate_recommendations(fish_name);
CREATE INDEX IF NOT EXISTS idx_tankmate_care_level ON fish_tankmate_recommendations(care_level);
CREATE INDEX IF NOT EXISTS idx_tankmate_confidence ON fish_tankmate_recommendations(confidence_score);

-- Enable Row Level Security if not already enabled
ALTER TABLE fish_tankmate_recommendations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public read access for tankmate recommendations" ON fish_tankmate_recommendations;
DROP POLICY IF EXISTS "Service role can manage tankmate recommendations" ON fish_tankmate_recommendations;

-- Create RLS policies
CREATE POLICY "Public read access for tankmate recommendations" 
ON fish_tankmate_recommendations FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Service role can manage tankmate recommendations" 
ON fish_tankmate_recommendations FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

-- Display table structure for verification
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'fish_tankmate_recommendations'
ORDER BY ordinal_position;

