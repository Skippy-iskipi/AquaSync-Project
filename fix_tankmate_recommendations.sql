-- Fix Fish Tankmate Recommendations Table
-- This script improves the table structure and regenerates accurate compatibility data

BEGIN;

-- Drop existing table if it exists
DROP TABLE IF EXISTS fish_tankmate_recommendations CASCADE;

-- Create improved fish_tankmate_recommendations table with better structure
CREATE TABLE fish_tankmate_recommendations (
    id SERIAL PRIMARY KEY,
    fish_name TEXT NOT NULL UNIQUE,
    
    -- Compatibility levels with separate arrays for better accuracy
    fully_compatible_tankmates TEXT[] DEFAULT '{}',
    conditional_tankmates JSONB DEFAULT '[]', -- Store conditions for each conditional tankmate
    incompatible_tankmates TEXT[] DEFAULT '{}',
    
    -- Summary counts
    total_fully_compatible INTEGER DEFAULT 0,
    total_conditional INTEGER DEFAULT 0,
    total_incompatible INTEGER DEFAULT 0,
    total_recommended INTEGER DEFAULT 0,
    
    -- Special requirements and care info
    special_requirements TEXT[] DEFAULT '{}',
    care_level TEXT,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    
    -- Metadata
    generation_method TEXT DEFAULT 'enhanced_attributes',
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_fish_tankmate_fish_name ON fish_tankmate_recommendations(fish_name);
CREATE INDEX idx_fish_tankmate_care_level ON fish_tankmate_recommendations(care_level);
CREATE INDEX idx_fish_tankmate_confidence ON fish_tankmate_recommendations(confidence_score);

-- Create compatibility matrix table for detailed pairwise compatibility
CREATE TABLE IF NOT EXISTS fish_compatibility_matrix (
    id SERIAL PRIMARY KEY,
    fish1_name TEXT NOT NULL,
    fish2_name TEXT NOT NULL,
    
    -- Compatibility assessment
    compatibility_level TEXT NOT NULL CHECK (compatibility_level IN ('compatible', 'conditional', 'incompatible')),
    is_compatible BOOLEAN NOT NULL, -- true for compatible/conditional, false for incompatible
    
    -- Detailed reasons and conditions
    compatibility_reasons TEXT[] NOT NULL,
    conditions TEXT[] DEFAULT '{}',
    
    -- Compatibility factors that led to this decision
    water_type_compatible BOOLEAN,
    temperature_compatible BOOLEAN,
    ph_compatible BOOLEAN,
    temperament_compatible BOOLEAN,
    size_compatible BOOLEAN,
    tank_zone_compatible BOOLEAN,
    
    -- Scoring and metadata
    compatibility_score DECIMAL(3,2) DEFAULT 0.0,
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    generation_method TEXT DEFAULT 'enhanced_attributes',
    
    -- Timestamps
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(fish1_name, fish2_name),
    CHECK (fish1_name != fish2_name)
);

-- Create indexes for compatibility matrix
CREATE INDEX idx_compatibility_fish1 ON fish_compatibility_matrix(fish1_name);
CREATE INDEX idx_compatibility_fish2 ON fish_compatibility_matrix(fish2_name);
CREATE INDEX idx_compatibility_level ON fish_compatibility_matrix(compatibility_level);
CREATE INDEX idx_compatibility_score ON fish_compatibility_matrix(compatibility_score);

-- Enable Row Level Security
ALTER TABLE fish_tankmate_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE fish_compatibility_matrix ENABLE ROW LEVEL SECURITY;

-- RLS Policies for fish_tankmate_recommendations
CREATE POLICY "Public read access for tankmate recommendations" 
ON fish_tankmate_recommendations FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Service role can manage tankmate recommendations" 
ON fish_tankmate_recommendations FOR ALL 
TO service_role 
USING (true);

CREATE POLICY "Authenticated users can read tankmate recommendations" 
ON fish_tankmate_recommendations FOR SELECT 
TO authenticated 
USING (true);

-- RLS Policies for fish_compatibility_matrix
CREATE POLICY "Public read access for compatibility matrix" 
ON fish_compatibility_matrix FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Service role can manage compatibility matrix" 
ON fish_compatibility_matrix FOR ALL 
TO service_role 
USING (true);

CREATE POLICY "Authenticated users can read compatibility matrix" 
ON fish_compatibility_matrix FOR SELECT 
TO authenticated 
USING (true);

-- Add comments for documentation
COMMENT ON TABLE fish_tankmate_recommendations IS 'Enhanced tankmate recommendations with compatibility levels and conditions';
COMMENT ON COLUMN fish_tankmate_recommendations.fully_compatible_tankmates IS 'Fish that are fully compatible without special conditions';
COMMENT ON COLUMN fish_tankmate_recommendations.conditional_tankmates IS 'Fish that are compatible with specific conditions (stored as JSON with conditions)';
COMMENT ON COLUMN fish_tankmate_recommendations.incompatible_tankmates IS 'Fish that are not compatible under any circumstances';
COMMENT ON COLUMN fish_tankmate_recommendations.special_requirements IS 'Special care requirements for this fish species';

COMMENT ON TABLE fish_compatibility_matrix IS 'Detailed pairwise compatibility matrix with reasons and conditions';
COMMENT ON COLUMN fish_compatibility_matrix.compatibility_level IS 'Compatibility level: compatible, conditional, or incompatible';
COMMENT ON COLUMN fish_compatibility_matrix.compatibility_reasons IS 'Reasons why fish are compatible/incompatible';
COMMENT ON COLUMN fish_compatibility_matrix.conditions IS 'Conditions required for conditional compatibility';

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updated_at
CREATE TRIGGER update_fish_tankmate_recommendations_updated_at 
    BEFORE UPDATE ON fish_tankmate_recommendations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fish_compatibility_matrix_updated_at 
    BEFORE UPDATE ON fish_compatibility_matrix 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;

-- Display table structure
SELECT 'fish_tankmate_recommendations table created successfully' as status;
SELECT 'fish_compatibility_matrix table created successfully' as status;
