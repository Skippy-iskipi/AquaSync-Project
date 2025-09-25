-- Update existing fish species with default values for new columns
-- This script will populate the NULL values in care_level, tank_level, description, and overfeeding_risks

-- Add the missing columns if they don't exist
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS overfeeding_risks TEXT;
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS bioload DECIMAL(3,1);
ALTER TABLE fish_species ADD COLUMN IF NOT EXISTS portion_grams DECIMAL(5,2);

-- Update care_level with default values based on temperament
UPDATE fish_species 
SET care_level = CASE 
    WHEN temperament = 'Peaceful' THEN 'Beginner'
    WHEN temperament = 'Semi-aggressive' THEN 'Intermediate'
    WHEN temperament = 'Aggressive' THEN 'Expert'
    ELSE 'Beginner'
END
WHERE care_level IS NULL;

-- Update tank_level with default values based on fish type
UPDATE fish_species 
SET tank_level = CASE 
    WHEN common_name ILIKE '%shrimp%' OR common_name ILIKE '%crab%' OR common_name ILIKE '%snail%' THEN 'Bottom'
    WHEN common_name ILIKE '%angelfish%' OR common_name ILIKE '%gourami%' OR common_name ILIKE '%betta%' THEN 'Top'
    WHEN common_name ILIKE '%tetra%' OR common_name ILIKE '%rasbora%' OR common_name ILIKE '%danio%' THEN 'Mid'
    ELSE 'All'
END
WHERE tank_level IS NULL;

-- Update description with basic descriptions
UPDATE fish_species 
SET description = CASE 
    WHEN water_type = 'Freshwater' THEN 'A popular freshwater fish species known for its beauty and ease of care.'
    WHEN water_type = 'Saltwater' THEN 'A beautiful marine fish species that adds color and life to saltwater aquariums.'
    ELSE 'A fascinating fish species with unique characteristics and care requirements.'
END
WHERE description IS NULL;

-- Update overfeeding_risks with general warnings
UPDATE fish_species 
SET overfeeding_risks = 'Overfeeding can lead to water quality issues, obesity, and health problems. Feed only what the fish can consume in 2-3 minutes, 1-2 times daily.'
WHERE overfeeding_risks IS NULL;

-- Update bioload with default values based on size
UPDATE fish_species 
SET bioload = CASE 
    WHEN "max_size_(cm)" <= 5 THEN 1
    WHEN "max_size_(cm)" <= 10 THEN 2
    WHEN "max_size_(cm)" <= 20 THEN 3
    WHEN "max_size_(cm)" <= 30 THEN 4
    ELSE 5
END
WHERE bioload IS NULL;

-- Update portion_grams with default values based on size
UPDATE fish_species 
SET portion_grams = CASE 
    WHEN "max_size_(cm)" <= 5 THEN 1
    WHEN "max_size_(cm)" <= 10 THEN 2
    WHEN "max_size_(cm)" <= 20 THEN 3
    WHEN "max_size_(cm)" <= 30 THEN 5
    ELSE 8
END
WHERE portion_grams IS NULL;

-- Verify the updates
SELECT 
    common_name,
    care_level,
    tank_level,
    CASE WHEN description IS NOT NULL THEN 'Has description' ELSE 'No description' END as desc_status,
    CASE WHEN overfeeding_risks IS NOT NULL THEN 'Has risks info' ELSE 'No risks info' END as risks_status,
    bioload,
    portion_grams
FROM fish_species 
LIMIT 10;
