-- Fix fish_compatibility_matrix table schema
-- This script adds missing columns required by the population script

-- Add missing columns if they don't exist
DO $$ 
BEGIN
    -- Add compatibility_reasons column (TEXT array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'compatibility_reasons'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN compatibility_reasons TEXT[] NOT NULL DEFAULT '{}';
        RAISE NOTICE 'Added compatibility_reasons column';
    END IF;

    -- Add conditions column (TEXT array)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'conditions'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN conditions TEXT[] DEFAULT '{}';
        RAISE NOTICE 'Added conditions column';
    END IF;

    -- Add compatibility_level column (TEXT with CHECK constraint)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'compatibility_level'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN compatibility_level TEXT NOT NULL DEFAULT 'unknown' 
        CHECK (compatibility_level IN ('compatible', 'conditional', 'incompatible', 'unknown'));
        RAISE NOTICE 'Added compatibility_level column';
    END IF;

    -- Add is_compatible column (BOOLEAN)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'is_compatible'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN is_compatible BOOLEAN NOT NULL DEFAULT false;
        RAISE NOTICE 'Added is_compatible column';
    END IF;

    -- Add compatibility_score column (DECIMAL)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'compatibility_score'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN compatibility_score DECIMAL(3,2) DEFAULT 0.0;
        RAISE NOTICE 'Added compatibility_score column';
    END IF;

    -- Add confidence_score column (DECIMAL)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'confidence_score'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN confidence_score DECIMAL(3,2) DEFAULT 0.0;
        RAISE NOTICE 'Added confidence_score column';
    END IF;

    -- Add generation_method column (TEXT)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'generation_method'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN generation_method TEXT DEFAULT 'enhanced_compatibility_system';
        RAISE NOTICE 'Added generation_method column';
    END IF;

    -- Add fish1_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'fish1_name'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN fish1_name TEXT NOT NULL;
        RAISE NOTICE 'Added fish1_name column';
    END IF;

    -- Add fish2_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fish_compatibility_matrix' 
        AND column_name = 'fish2_name'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD COLUMN fish2_name TEXT NOT NULL;
        RAISE NOTICE 'Added fish2_name column';
    END IF;

END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_compatibility_fish1 ON fish_compatibility_matrix(fish1_name);
CREATE INDEX IF NOT EXISTS idx_compatibility_fish2 ON fish_compatibility_matrix(fish2_name);
CREATE INDEX IF NOT EXISTS idx_compatibility_level ON fish_compatibility_matrix(compatibility_level);
CREATE INDEX IF NOT EXISTS idx_compatibility_score ON fish_compatibility_matrix(compatibility_score);
CREATE INDEX IF NOT EXISTS idx_is_compatible ON fish_compatibility_matrix(is_compatible);

-- Add unique constraint to prevent duplicate fish pairs
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_fish_pair'
    ) THEN
        ALTER TABLE fish_compatibility_matrix 
        ADD CONSTRAINT unique_fish_pair UNIQUE(fish1_name, fish2_name);
        RAISE NOTICE 'Added unique constraint for fish pairs';
    END IF;
END $$;

-- Enable Row Level Security if not already enabled
ALTER TABLE fish_compatibility_matrix ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public read access for compatibility matrix" ON fish_compatibility_matrix;
DROP POLICY IF EXISTS "Service role can manage compatibility matrix" ON fish_compatibility_matrix;

-- Create RLS policies
CREATE POLICY "Public read access for compatibility matrix" 
ON fish_compatibility_matrix FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Service role can manage compatibility matrix" 
ON fish_compatibility_matrix FOR ALL 
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
WHERE table_name = 'fish_compatibility_matrix'
ORDER BY ordinal_position;

