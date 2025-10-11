# Fix Database Schema for Compatibility Population

## Problem
The error `Could not find the 'compatibility_reasons' column of 'fish_compatibility_matrix' in the schema cache` indicates that your database tables are missing required columns.

## Solution

Follow these steps to fix your database schema:

### Step 1: Run the SQL Scripts in Supabase

Go to your **Supabase Dashboard** → **SQL Editor** and run these two SQL scripts in order:

#### 1. Fix `fish_compatibility_matrix` table
Run the contents of: `fix_compatibility_matrix_schema.sql`

This script will:
- Add missing columns: `compatibility_reasons`, `conditions`, `compatibility_level`, `is_compatible`, `compatibility_score`, `confidence_score`, `generation_method`
- Create necessary indexes for performance
- Set up Row Level Security (RLS) policies
- Create unique constraint for fish pairs

#### 2. Fix `fish_tankmate_recommendations` table
Run the contents of: `fix_tankmate_recommendations_schema.sql`

This script will:
- Add missing columns: `fully_compatible_tankmates`, `conditional_tankmates`, `incompatible_tankmates`, `special_requirements`, `care_level`, `confidence_score`, `total_fully_compatible`, `total_conditional`, `total_incompatible`, `total_recommended`
- Create necessary indexes
- Set up Row Level Security (RLS) policies

### Step 2: Verify the Schema

After running both scripts, you should see output showing all columns for each table. Verify that you have:

#### fish_compatibility_matrix columns:
- `id` (SERIAL PRIMARY KEY)
- `fish1_name` (TEXT)
- `fish2_name` (TEXT)
- `compatibility_level` (TEXT) - values: 'compatible', 'conditional', 'incompatible'
- `is_compatible` (BOOLEAN)
- `compatibility_reasons` (TEXT[]) - **This was missing!**
- `conditions` (TEXT[])
- `compatibility_score` (DECIMAL 3,2) - range: 0.00 to 9.99
- `confidence_score` (DECIMAL 3,2) - range: 0.00 to 9.99
- `generation_method` (TEXT)
- `created_at` (TIMESTAMP)

#### fish_tankmate_recommendations columns:
- `id` (SERIAL PRIMARY KEY)
- `fish_name` (TEXT UNIQUE)
- `fully_compatible_tankmates` (TEXT[])
- `conditional_tankmates` (JSONB)
- `incompatible_tankmates` (TEXT[])
- `special_requirements` (TEXT[])
- `care_level` (TEXT)
- `confidence_score` (DECIMAL 3,2)
- `total_fully_compatible` (INTEGER)
- `total_conditional` (INTEGER)
- `total_incompatible` (INTEGER)
- `total_recommended` (INTEGER)
- `created_at` (TIMESTAMP)

### Step 3: Re-run the Population Script

After fixing the database schema, run the population script again:

```bash
cd backend
python run_compatibility_population.py
```

## Expected Output

You should see:
```
🔧 Compatibility Data Population Script
==================================================
🚀 Starting compatibility data population...
📊 Found [N] fish species
🔄 Calculating compatibility matrix...
   Processing pair 1/[total]: [Fish1] + [Fish2]
   ...
✅ Generated [N] compatibility entries
🔄 Generating tankmate recommendations...
   Processing tankmates for: [Fish Name]
   ...
✅ Generated [N] tankmate recommendation entries
🔄 Uploading to database...
   Clearing existing data...
   🔍 Debugging first few records...
   Uploading compatibility matrix in batches...
     Uploading batch 1/[total] ([N] records)
     ✅ Batch 1 uploaded successfully
   ...
   Uploading tankmate recommendations in batches...
     Uploading batch 1/[total] ([N] records)
     ✅ Batch 1 uploaded successfully
   ...
🎉 Database population completed successfully!
📈 Final Statistics:
   - Fish species processed: [N]
   - Compatibility pairs: [N]
   - Tankmate recommendations: [N]
```

## Troubleshooting

### Error: "duplicate key value violates unique constraint"
**Solution:** Clear the existing data first by running in Supabase SQL Editor:
```sql
DELETE FROM fish_compatibility_matrix;
DELETE FROM fish_tankmate_recommendations;
```

### Error: "numeric field overflow"
**Solution:** This is already handled in the script with `validate_numeric_values()` function that caps scores at 9.99

### Error: "permission denied"
**Solution:** The script uses the `SUPABASE_SERVICE_KEY` to bypass RLS policies. Make sure it's correctly configured in `run_compatibility_population.py`

## What This Script Does

1. **Fetches all fish species** from your `fish_species` table
2. **Calculates compatibility** for every fish pair using the same logic as your mobile app
3. **Generates tankmate recommendations** based on compatibility results
4. **Uploads data in batches** to prevent timeouts and memory issues
5. **Validates all numeric values** to prevent database constraint violations

## Data Quality

The script uses:
- ✅ **Real fish data** from your database (not AI-generated)
- ✅ **Enhanced compatibility logic** (same as your API endpoints)
- ✅ **Conditional compatibility support** (e.g., "compatible if tank is large enough")
- ✅ **Confidence scoring** based on data completeness
- ✅ **Special requirements** generated from fish characteristics

## Notes

- The population process may take several minutes depending on the number of fish species
- All existing data in both tables will be cleared before new data is inserted
- The script uses batch uploads (100 records per batch) for efficiency
- All numeric scores are properly scaled and validated to fit database constraints

