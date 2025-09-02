# Fix Fish Tankmate Recommendations Table

This guide will help you fix the `fish_tankmate_recommendations` table in your Supabase database to improve accuracy and separate compatibility levels properly.

## What This Fix Does

1. **Improves Table Structure**: Creates a better table schema with separate arrays for different compatibility levels
2. **Separates Compatibility Levels**: Distinguishes between fully compatible, conditional, and incompatible tankmates
3. **Adds Manual Compatibility Rules**: Includes curated rules for problematic fish combinations (Betta, Flowerhorn, etc.)
4. **Regenerates Accurate Data**: Uses enhanced compatibility logic to recalculate all recommendations
5. **Creates Detailed Matrix**: Adds a compatibility matrix table for detailed pairwise analysis

## Files Created

- `fix_tankmate_recommendations.sql` - SQL script to fix table structure
- `backend/scripts/fix_tankmate_recommendations.py` - Python script to regenerate data
- `fix_tankmate_recommendations.bat` - Windows batch file to run the fix
- `TANKMATE_FIX_README.md` - This documentation

## Step-by-Step Instructions

### Step 1: Fix Database Table Structure

1. **Open your Supabase Dashboard**
   - Go to [supabase.com](https://supabase.com)
   - Sign in and select your project

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Run the SQL Fix**
   - Copy the entire contents of `fix_tankmate_recommendations.sql`
   - Paste it into the SQL editor
   - Click "Run" to execute

4. **Verify Tables Created**
   - Go to "Table Editor" in the left sidebar
   - You should see two new tables:
     - `fish_tankmate_recommendations` (improved structure)
     - `fish_compatibility_matrix` (new detailed matrix)

### Step 2: Regenerate Compatibility Data

1. **Open Command Prompt/Terminal**
   - Navigate to your project directory

2. **Run the Fix Script**
   ```bash
   # Windows
   fix_tankmate_recommendations.bat
   
   # Or manually:
   cd backend/scripts
   python fix_tankmate_recommendations.py
   ```

3. **Wait for Completion**
   - The script will process all fish species
   - This may take several minutes depending on the number of fish
   - Progress will be displayed in the console

### Step 3: Verify Results

1. **Check Generated Files**
   - `fixed_compatibility_matrix.json` - Detailed compatibility data
   - `fixed_tankmate_recommendations.json` - Tankmate recommendations
   - `fixed_compatibility_summary.json` - Summary statistics

2. **Check Database**
   - Go to Supabase Table Editor
   - View the new data in both tables
   - Verify that compatibility levels are properly separated

## What's Improved

### Before (Old Structure)
- Single `compatible_tankmates` array
- No distinction between compatibility levels
- Inaccurate recommendations mixed together
- Limited compatibility logic

### After (New Structure)
- **`fully_compatible_tankmates`**: Fish that can live together without issues
- **`conditional_tankmates`**: Fish that can live together with specific conditions
- **`incompatible_tankmates`**: Fish that should never be kept together
- **Detailed conditions**: Specific requirements for conditional compatibility
- **Manual rules**: Curated compatibility rules for problematic species

## Manual Compatibility Rules Added

The script includes manual rules for these problematic fish:

### Betta Fish
- **Fully Compatible**: Corydoras, Kuhli Loach, Snails, Shrimp
- **Conditional**: Neon Tetra, Ember Tetra (with 20+ gallon tank)
- **Incompatible**: Guppies, Angelfish, Tiger Barbs, Other Bettas

### Flowerhorn Cichlid
- **Fully Compatible**: None (too aggressive)
- **Conditional**: Other large aggressive cichlids (75+ gallon tank)
- **Incompatible**: Peaceful fish, small fish

### Goldfish
- **Fully Compatible**: Other goldfish, White Cloud Minnows
- **Conditional**: Cold-water plecos
- **Incompatible**: Tropical fish, warm-water species

### Marine Fish (Blue Tang, etc.)
- **Fully Compatible**: Other marine species
- **Conditional**: Other tangs, angelfish (with large tanks)
- **Incompatible**: Freshwater fish

## API Changes

Your existing API endpoints will continue to work, but you now have access to more detailed data:

### New Endpoint Structure
```json
{
  "fish_name": "Betta",
  "fully_compatible_tankmates": ["Corydoras", "Kuhli Loach"],
  "conditional_tankmates": [
    {
      "name": "Neon Tetra",
      "conditions": ["20+ gallon tank", "Monitor for fin nipping"]
    }
  ],
  "incompatible_tankmates": ["Guppy", "Angelfish"],
  "total_fully_compatible": 2,
  "total_conditional": 1,
  "total_recommended": 3
}
```

### Backward Compatibility
The old `compatible_tankmates` field is replaced, but you can reconstruct it by combining:
```python
all_recommended = fully_compatible + [fish["name"] for fish in conditional_tankmates]
```

## Troubleshooting

### Common Issues

1. **SQL Execution Errors**
   - Ensure you have admin access to your Supabase project
   - Check that the SQL syntax is correct for your PostgreSQL version

2. **Python Script Errors**
   - Verify all dependencies are installed
   - Check that your Supabase credentials are correct
   - Ensure the `fish_species` table exists and has data

3. **Missing Data**
   - The script requires existing fish data in the `fish_species` table
   - Run the enhanced fish scraper first if you need more fish data

### Performance Notes

- **Large Datasets**: Processing 100+ fish species may take 10-30 minutes
- **Memory Usage**: The script loads all fish data into memory
- **Database Load**: Large batch inserts may temporarily impact database performance

## Rollback Plan

If you need to revert the changes:

1. **Restore Old Table Structure**
   ```sql
   -- Drop new tables
   DROP TABLE IF EXISTS fish_tankmate_recommendations CASCADE;
   DROP TABLE IF EXISTS fish_compatibility_matrix CASCADE;
   
   -- Recreate old structure
   CREATE TABLE fish_tankmate_recommendations (
       id SERIAL PRIMARY KEY,
       fish_name TEXT NOT NULL UNIQUE,
       compatible_tankmates TEXT[] NOT NULL,
       total_compatible INTEGER NOT NULL,
       calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   );
   ```

2. **Restore Old Data**
   - Use your backup files or restore from version control
   - Re-run the old compatibility generation script

## Support

If you encounter issues:

1. Check the console output for error messages
2. Verify your Supabase credentials and permissions
3. Ensure all required Python packages are installed
4. Check that your database has the required fish data

## Next Steps

After completing this fix:

1. **Test the New API**: Verify that compatibility checks work correctly
2. **Update Frontend**: Modify your app to display the new compatibility levels
3. **Monitor Performance**: Watch for any performance issues with the new structure
4. **Regular Updates**: Consider running this script periodically as you add new fish species
