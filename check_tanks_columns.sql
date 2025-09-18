-- Check current columns in tanks table
-- Run this to see what columns currently exist

SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'tanks' 
ORDER BY ordinal_position;
