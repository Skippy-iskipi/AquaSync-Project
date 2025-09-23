-- Add active column to fish_species table
ALTER TABLE fish_species
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;

-- Update existing fish species to be active by default
UPDATE fish_species
SET active = true
WHERE active IS NULL;

-- Add an index for better performance
CREATE INDEX IF NOT EXISTS idx_fish_species_active ON fish_species(active);

-- Add updated_at column if it doesn't exist
ALTER TABLE fish_species
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have current timestamp
UPDATE fish_species
SET updated_at = NOW()
WHERE updated_at IS NULL;
