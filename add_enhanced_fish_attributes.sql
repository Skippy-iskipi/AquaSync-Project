-- Enhanced Fish Attributes Migration
-- Adds comprehensive compatibility attributes to fish_species table

-- Water parameter attributes
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS temperature_min DECIMAL(4,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS temperature_max DECIMAL(4,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS ph_min DECIMAL(3,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS ph_max DECIMAL(3,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS hardness_min DECIMAL(4,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS hardness_max DECIMAL(4,1);

-- Behavioral attributes
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS activity_level TEXT CHECK (activity_level IN ('Low', 'Moderate', 'High', 'Nocturnal'));
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS tank_zone TEXT CHECK (tank_zone IN ('Top', 'Mid', 'Bottom', 'All'));

-- Compatibility factors
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS fin_vulnerability TEXT CHECK (fin_vulnerability IN ('Hardy', 'Moderate', 'Vulnerable'));
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS fin_nipper BOOLEAN DEFAULT FALSE;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS breeding_behavior TEXT CHECK (breeding_behavior IN ('Egg scatterer', 'Egg layer', 'Mouthbrooder', 'Bubble nester', 'Live bearer', 'No breeding'));

-- Special requirements
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS reef_safe BOOLEAN;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS schooling_min_number INTEGER DEFAULT 1;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS territorial_space_cm DECIMAL(5,1) DEFAULT 0.0;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS hiding_spots_required BOOLEAN DEFAULT FALSE;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS strong_current_needed BOOLEAN DEFAULT FALSE;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS special_diet_requirements TEXT;

-- Care and data quality
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS care_level TEXT CHECK (care_level IN ('Beginner', 'Intermediate', 'Expert'));
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS confidence_score DECIMAL(3,2) DEFAULT 0.0;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS data_sources TEXT[];
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_fish_species_water_type ON fish_species(water_type);
CREATE INDEX IF NOT EXISTS idx_fish_species_temperament ON fish_species(temperament);
CREATE INDEX IF NOT EXISTS idx_fish_species_social_behavior ON fish_species(social_behavior);
CREATE INDEX IF NOT EXISTS idx_fish_species_activity_level ON fish_species(activity_level);
CREATE INDEX IF NOT EXISTS idx_fish_species_tank_zone ON fish_species(tank_zone);
CREATE INDEX IF NOT EXISTS idx_fish_species_reef_safe ON fish_species(reef_safe);
CREATE INDEX IF NOT EXISTS idx_fish_species_fin_nipper ON fish_species(fin_nipper);

-- Add comments for documentation
COMMENT ON COLUMN fish_species.temperature_min IS 'Minimum temperature requirement in Celsius';
COMMENT ON COLUMN fish_species.temperature_max IS 'Maximum temperature requirement in Celsius';
COMMENT ON COLUMN fish_species.ph_min IS 'Minimum pH requirement';
COMMENT ON COLUMN fish_species.ph_max IS 'Maximum pH requirement';
COMMENT ON COLUMN fish_species.hardness_min IS 'Minimum water hardness in dGH';
COMMENT ON COLUMN fish_species.hardness_max IS 'Maximum water hardness in dGH';
COMMENT ON COLUMN fish_species.activity_level IS 'Fish activity level: Low, Moderate, High, Nocturnal';
COMMENT ON COLUMN fish_species.tank_zone IS 'Preferred tank zone: Top, Mid, Bottom, All';
COMMENT ON COLUMN fish_species.fin_vulnerability IS 'Vulnerability to fin nipping: Hardy, Moderate, Vulnerable';
COMMENT ON COLUMN fish_species.fin_nipper IS 'Whether this fish nips fins of other fish';
COMMENT ON COLUMN fish_species.breeding_behavior IS 'How the fish breeds in aquarium conditions';
COMMENT ON COLUMN fish_species.reef_safe IS 'Safe for reef aquariums (saltwater only)';
COMMENT ON COLUMN fish_species.schooling_min_number IS 'Minimum number needed if schooling fish';
COMMENT ON COLUMN fish_species.territorial_space_cm IS 'Territory diameter needed in centimeters';
COMMENT ON COLUMN fish_species.hiding_spots_required IS 'Whether fish requires hiding spots';
COMMENT ON COLUMN fish_species.strong_current_needed IS 'Whether fish needs strong water current';
COMMENT ON COLUMN fish_species.special_diet_requirements IS 'Any special dietary needs';
COMMENT ON COLUMN fish_species.care_level IS 'Difficulty level: Beginner, Intermediate, Expert';
COMMENT ON COLUMN fish_species.confidence_score IS 'Data reliability score (0.0-1.0)';
COMMENT ON COLUMN fish_species.data_sources IS 'Array of data source names';
COMMENT ON COLUMN fish_species.last_updated IS 'When this record was last updated';

-- Update existing records with default values where appropriate
UPDATE fish_species SET 
    confidence_score = 0.5,
    data_sources = ARRAY['legacy_data'],
    last_updated = NOW()
WHERE confidence_score IS NULL OR confidence_score = 0.0;
