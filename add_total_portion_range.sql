-- Adds an optional text column to store total portion ranges like '24-40'
ALTER TABLE IF EXISTS diet_calculations
ADD COLUMN IF NOT EXISTS total_portion_range TEXT;
