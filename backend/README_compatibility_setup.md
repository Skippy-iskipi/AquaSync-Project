# Compatibility Data Population Setup

This guide explains how to populate the `fish_compatibility_matrix` and `fish_tankmate_recommendations` tables with real data from the `fish_species` table instead of AI-generated content.

## Overview

The system now uses:
- **Real fish data** from the `fish_species` table
- **Enhanced compatibility logic** from `conditional_compatibility.py` and `enhanced_compatibility_integration.py`
- **Structured tankmate recommendations** based on actual compatibility calculations

## Prerequisites

1. **Supabase Database**: Ensure your `fish_species` table is populated with fish data
2. **Python Environment**: Make sure you have the required Python packages installed
3. **Database Access**: Ensure your Supabase credentials are properly configured

## Required Database Tables

### 1. fish_compatibility_matrix
```sql
CREATE TABLE fish_compatibility_matrix (
    id SERIAL PRIMARY KEY,
    fish1_name TEXT NOT NULL,
    fish2_name TEXT NOT NULL,
    compatibility_level TEXT NOT NULL, -- 'compatible', 'conditional', 'incompatible'
    is_compatible BOOLEAN NOT NULL,
    compatibility_reasons TEXT[] NOT NULL,
    conditions TEXT[] NOT NULL,
    compatibility_score FLOAT NOT NULL, -- 0-100
    confidence_score FLOAT NOT NULL, -- 0-100
    generation_method TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 2. fish_tankmate_recommendations
```sql
CREATE TABLE fish_tankmate_recommendations (
    id SERIAL PRIMARY KEY,
    fish_name TEXT NOT NULL UNIQUE,
    fully_compatible_tankmates TEXT[] NOT NULL,
    conditional_tankmates JSONB NOT NULL, -- Array of {name, conditions}
    incompatible_tankmates TEXT[] NOT NULL,
    special_requirements TEXT[] NOT NULL,
    care_level TEXT NOT NULL,
    confidence_score FLOAT NOT NULL,
    total_fully_compatible INTEGER NOT NULL,
    total_conditional INTEGER NOT NULL,
    total_incompatible INTEGER NOT NULL,
    total_recommended INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## Running the Population Script

### Step 1: Navigate to Backend Directory
```bash
cd backend
```

### Step 2: Run the Population Script
```bash
python run_compatibility_population.py
```

This script will:
1. **Fetch fish species** from your `fish_species` table (limited to 20 for testing)
2. **Calculate compatibility** for all fish pairs using the enhanced compatibility system
3. **Generate tankmate recommendations** for each fish based on compatibility results
4. **Upload data** to the `fish_compatibility_matrix` and `fish_tankmate_recommendations` tables

### Step 3: Verify Results
Check your Supabase dashboard to see the populated tables:
- `fish_compatibility_matrix` should contain compatibility data for all fish pairs
- `fish_tankmate_recommendations` should contain tankmate recommendations for each fish

## Sample Output

```
🚀 Starting compatibility data population...
📊 Found 20 fish species
🔄 Calculating compatibility matrix...
   Processing pair 1/190: Betta + Angelfish
   Processing pair 2/190: Betta + Neon Tetra
   ...
✅ Generated 190 compatibility entries
🔄 Generating tankmate recommendations...
   Processing tankmates for: Betta
   Processing tankmates for: Angelfish
   ...
✅ Generated 20 tankmate recommendation entries
🔄 Uploading to database...
   Clearing existing data...
   Uploading compatibility matrix...
   Uploading tankmate recommendations...
🎉 Database population completed successfully!
```

## For Production (Full Dataset)

To populate with all fish species (not just 20), modify the script:

```python
# In run_compatibility_population.py, change this line:
fish_species = await get_fish_species_sample(20)  # Change 20 to None or a larger number

# And update the get_fish_species_sample function:
async def get_fish_species_sample(limit: int = None) -> List[Dict[str, Any]]:
    db = get_supabase_client()
    query = db.table('fish_species').select('*')
    if limit:
        query = query.limit(limit)
    response = query.execute()
    return response.data
```

## Troubleshooting

### Common Issues:

1. **"No fish species found"**: Check that your `fish_species` table has data
2. **"Error uploading to database"**: Verify your Supabase credentials and table structure
3. **"Error calculating compatibility"**: Check that the compatibility modules are properly imported

### Debug Mode:
Add debug prints to see what's happening:
```python
print(f"Fish data: {fish}")
print(f"Compatibility result: {compatibility_entry}")
```

## Data Quality

The system calculates:
- **Compatibility scores** (0-100) based on fish characteristics
- **Confidence scores** (0-100) based on data completeness
- **Special requirements** based on fish temperament, water type, and behavior
- **Realistic tankmate recommendations** based on actual compatibility logic

## Next Steps

After populating the data:
1. **Test the Flutter app** to ensure compatibility checking works correctly
2. **Verify fish images** are displaying properly
3. **Check tankmate recommendations** are showing relevant suggestions
4. **Monitor performance** and adjust batch sizes if needed

## Support

If you encounter issues:
1. Check the console output for error messages
2. Verify your database table structure matches the requirements
3. Ensure all required Python modules are installed
4. Check your Supabase connection and permissions
