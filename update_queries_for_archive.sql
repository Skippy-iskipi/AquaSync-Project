-- Update existing queries to filter out archived records
-- This ensures that archived records don't appear in the app

-- Note: You'll need to update your application code to include these WHERE clauses
-- when querying the database. Here are the recommended WHERE clauses:

-- For fish_predictions queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For water_calculations queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For fish_calculations queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For compatibility_results queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For diet_calculations queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For fish_volume_calculations queries:
-- WHERE archived = FALSE OR archived IS NULL

-- For tanks queries:
-- WHERE archived = FALSE OR archived IS NULL

-- Example of how to update your application queries:
-- 
-- OLD QUERY:
-- SELECT * FROM fish_predictions WHERE user_id = $1;
-- 
-- NEW QUERY:
-- SELECT * FROM fish_predictions 
-- WHERE user_id = $1 
-- AND (archived = FALSE OR archived IS NULL)
-- ORDER BY created_at DESC;

-- You may also want to create views for easier querying:

-- Create views for non-archived records
CREATE OR REPLACE VIEW active_fish_predictions AS
SELECT * FROM fish_predictions 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_water_calculations AS
SELECT * FROM water_calculations 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_fish_calculations AS
SELECT * FROM fish_calculations 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_compatibility_results AS
SELECT * FROM compatibility_results 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_diet_calculations AS
SELECT * FROM diet_calculations 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_fish_volume_calculations AS
SELECT * FROM fish_volume_calculations 
WHERE archived = FALSE OR archived IS NULL;

CREATE OR REPLACE VIEW active_tanks AS
SELECT * FROM tanks 
WHERE archived = FALSE OR archived IS NULL;

-- Grant permissions on views (adjust as needed for your setup)
GRANT SELECT ON active_fish_predictions TO authenticated;
GRANT SELECT ON active_water_calculations TO authenticated;
GRANT SELECT ON active_fish_calculations TO authenticated;
GRANT SELECT ON active_compatibility_results TO authenticated;
GRANT SELECT ON active_diet_calculations TO authenticated;
GRANT SELECT ON active_fish_volume_calculations TO authenticated;
GRANT SELECT ON active_tanks TO authenticated;
