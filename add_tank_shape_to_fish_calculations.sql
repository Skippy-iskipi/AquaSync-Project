-- Add tank_shape column to fish_calculations table
ALTER TABLE fish_calculations 
ADD COLUMN IF NOT EXISTS tank_shape TEXT;

-- Add a comment to describe the column
COMMENT ON COLUMN fish_calculations.tank_shape IS 'Tank shape type: bowl, rectangle, or cylinder';

-- Optional: Update existing records with a default value if needed
-- UPDATE fish_calculations 
-- SET tank_shape = 'rectangle' 
-- WHERE tank_shape IS NULL;

