BEGIN;

-- Create temporary backup table
CREATE TEMP TABLE fish_backup AS SELECT * FROM fish_species;

-- Drop existing table
DROP TABLE fish_species;

-- Create new table with id column
CREATE TABLE fish_species (
    id SERIAL PRIMARY KEY,
    common_name VARCHAR(100) NOT NULL,
    scientific_name VARCHAR(100) NOT NULL,
    water_type VARCHAR(50) NOT NULL,
    "max_size_(cm)" NUMERIC(10, 2),
    temperament VARCHAR(50),
    "temperature_range_(°c)" VARCHAR(50),
    ph_range VARCHAR(50),
    habitat_type VARCHAR(100),
    social_behavior VARCHAR(50),
    tank_level VARCHAR(50),
    "minimum_tank_size_(l)" INTEGER,
    compatibility_notes TEXT,
    diet VARCHAR(50),
    lifespan VARCHAR(50),
    care_level VARCHAR(50),
    preferred_food VARCHAR(100),
    feeding_frequency VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert data from backup
INSERT INTO fish_species (
    common_name,
    scientific_name,
    water_type,
    "max_size_(cm)",
    temperament,
    "temperature_range_(°c)",
    ph_range,
    habitat_type,
    social_behavior,
    tank_level,
    "minimum_tank_size_(l)",
    compatibility_notes,
    diet,
    lifespan,
    care_level,
    preferred_food,
    feeding_frequency
)
SELECT
    common_name,
    scientific_name,
    water_type,
    "max_size_(cm)",
    temperament,
    "temperature_range_(°c)",
    ph_range,
    habitat_type,
    social_behavior,
    tank_level,
    "minimum_tank_size_(l)",
    compatibility_notes,
    diet,
    lifespan,
    care_level,
    preferred_food,
    feeding_frequency
FROM fish_backup;

-- Drop backup table
DROP TABLE fish_backup;

COMMIT; 