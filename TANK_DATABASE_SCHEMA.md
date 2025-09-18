# Tank Database Schema Documentation

## Overview
This document describes the comprehensive database schema for the tank management system, including all fields used in the `add_edit_tank.dart` form and displayed in `tank_management.dart`.

## Table: `tanks`

### Core Tank Information
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `id` | UUID | Primary key | `gen_random_uuid()` |
| `user_id` | UUID | Foreign key to auth.users | `auth.uid()` |
| `name` | TEXT | Tank name | `"My Aquarium"` |
| `tank_shape` | TEXT | Tank shape type | `"rectangle"`, `"bowl"`, `"cylinder"` |
| `length` | DECIMAL(10,2) | Tank length | `60.00` |
| `width` | DECIMAL(10,2) | Tank width | `30.00` |
| `height` | DECIMAL(10,2) | Tank height | `40.00` |
| `unit` | TEXT | Measurement unit | `"CM"`, `"IN"` |
| `volume` | DECIMAL(10,2) | Calculated volume in liters | `72.00` |

### Fish Management
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `fish_selections` | JSONB | Fish species and quantities | `{"Goldfish": 2, "Koi": 1}` |
| `fish_details` | JSONB | Detailed fish information | `{"Goldfish": {"portion_grams": 5.0, "feeding_frequency": 2}}` |
| `compatibility_results` | JSONB | Fish compatibility analysis | `{"has_incompatible_pairs": false, "incompatible_pairs": []}` |
| `recommended_fish_quantities` | JSONB | AI-recommended fish quantities | `{"Goldfish": 3, "Koi": 1}` |

### Feed Management
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `available_feeds` | JSONB | Available feed types and amounts | `{"Pellets": 500.0, "Flakes": 300.0}` |
| `feed_inventory` | JSONB | Detailed feed inventory | `{"Pellets": {"quantity": 500, "unit": "g"}}` |
| `feed_portion_data` | JSONB | Portion data per fish | `{"Goldfish": {"daily_portion": 10.0}}` |
| `feed_duration_data` | JSONB | Feed consumption calculations | `{"Pellets": {"days_remaining": 30, "daily_consumption": 16.67}}` |
| `incompatible_feeds` | JSONB | Feed compatibility analysis | `{"Bloodworms": ["Goldfish"]}` |
| `feed_recommendations` | JSONB | AI feed recommendations | `{"recommended": ["Pellets", "Flakes"]}` |

### Feeding Recommendations
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `feeding_recommendations` | JSONB | AI feeding recommendations | `{"schedule": "2x daily", "portions": "5g per fish"}` |

### UI State Management
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `current_step` | INTEGER | Current form step | `0` (Tank Setup), `1` (Fish Selection), `2` (Feed Inventory), `3` (Summary) |
| `form_validation_status` | JSONB | Form validation status | `{"tank_setup": true, "fish_selection": false}` |
| `ui_state` | JSONB | UI state preservation | `{"selected_feed": "Pellets", "expanded_sections": ["fish"]}` |
| `tank_shape_warnings` | JSONB | Tank shape compatibility warnings | `{"Goldfish": "Too large for bowl tank"}` |

### Calculation Metadata
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `calculation_metadata` | JSONB | Calculation steps and metadata | `{"volume_calculation": "60*30*40/1000", "feed_calculations": {...}}` |

### Timestamps
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `date_created` | TIMESTAMP WITH TIME ZONE | Creation timestamp | `2024-01-15 10:30:00+00` |
| `last_updated` | TIMESTAMP WITH TIME ZONE | Last update timestamp | `2024-01-15 14:45:00+00` |
| `created_at` | TIMESTAMP WITH TIME ZONE | Creation timestamp (legacy) | `2024-01-15 10:30:00+00` |

## JSONB Field Structures

### fish_selections
```json
{
  "Goldfish": 2,
  "Koi": 1,
  "Betta": 3
}
```

### fish_details
```json
{
  "Goldfish": {
    "common_name": "Goldfish",
    "portion_grams": 5.0,
    "feeding_frequency": 2,
    "preferred_food": "pellets, flakes",
    "max_size_cm": 30.0,
    "temperament": "peaceful",
    "water_type": "freshwater"
  }
}
```

### compatibility_results
```json
{
  "has_incompatible_pairs": false,
  "has_conditional_pairs": true,
  "incompatible_pairs": [],
  "conditional_pairs": [
    {
      "pair": ["Goldfish", "Koi"],
      "reasons": ["Similar dietary requirements"],
      "type": "conditional"
    }
  ]
}
```

### available_feeds
```json
{
  "Pellets": 500.0,
  "Flakes": 300.0,
  "Bloodworms": 100.0
}
```

### feed_duration_data
```json
{
  "Pellets": {
    "available_grams": 500.0,
    "daily_consumption": 16.67,
    "days_remaining": 30,
    "hours_remaining": 720,
    "fish_consumption": {
      "Goldfish": 10.0,
      "Koi": 6.67
    },
    "is_low_stock": false,
    "is_critical": false
  }
}
```

### incompatible_feeds
```json
{
  "Bloodworms": ["Goldfish"],
  "Vegetable": ["Betta"]
}
```

### feed_recommendations
```json
{
  "recommended": ["Pellets", "Flakes", "Spirulina"],
  "incompatible": ["Bloodworms", "Live Food"],
  "reasoning": {
    "Pellets": "Suitable for omnivorous fish",
    "Bloodworms": "Not suitable for herbivorous fish"
  }
}
```

### feeding_recommendations
```json
{
  "feeding_schedule": "2 times daily",
  "portion_per_feeding": "5g per fish",
  "feeding_notes": "Feed in morning and evening",
  "total_daily_food": "30g"
}
```

### tank_shape_warnings
```json
{
  "Goldfish": "Goldfish is too large for a bowl tank. Bowl tanks are small and only suitable for tiny fish like bettas or small tetras.",
  "Koi": "Koi needs more swimming space than a cylinder tank provides. Cylinder tanks are tall but narrow, limiting swimming space."
}
```

### form_validation_status
```json
{
  "tank_setup": true,
  "fish_selection": true,
  "feed_inventory": false,
  "summary": false
}
```

### ui_state
```json
{
  "selected_feed": "Pellets",
  "expanded_sections": ["fish_selection", "feed_inventory"],
  "form_controllers": {
    "name": "My Aquarium",
    "length": "60",
    "width": "30",
    "height": "40"
  }
}
```

### calculation_metadata
```json
{
  "volume_calculation": {
    "formula": "length * width * height / 1000",
    "steps": "60 * 30 * 40 / 1000 = 72.0 L",
    "result": 72.0
  },
  "feed_calculations": {
    "last_calculated": "2024-01-15T10:30:00Z",
    "fish_data_source": "fish_species_table",
    "calculation_method": "portion_grams * feeding_frequency * fish_count"
  }
}
```

## Indexes

### Performance Indexes
- `idx_tanks_user_id` - User-based queries
- `idx_tanks_created_at` - Chronological ordering
- `idx_tanks_current_step` - Step-based filtering

### JSONB Indexes (GIN)
- `idx_tanks_fish_selections` - Fish selection queries
- `idx_tanks_available_feeds` - Feed inventory queries
- `idx_tanks_compatibility_results` - Compatibility analysis
- `idx_tanks_feed_duration_data` - Feed duration calculations
- `idx_tanks_fish_details` - Fish details queries
- `idx_tanks_tank_shape_warnings` - Shape compatibility warnings

## Constraints

### Check Constraints
- `check_tank_shape` - Validates tank_shape values
- `check_unit` - Validates unit values
- `check_volume_positive` - Ensures positive volume
- `check_dimensions_positive` - Ensures positive dimensions
- `check_current_step_range` - Validates step range (0-3)

### Validation Functions
- `validate_fish_selections()` - Validates fish selection JSONB
- `validate_available_feeds()` - Validates feed data JSONB

## Views

### tank_summary
Provides a simplified view of tank data for quick queries:
```sql
SELECT * FROM tank_summary WHERE user_id = 'user-uuid';
```

## Functions

### get_tank_stats(tank_id)
Returns comprehensive statistics for a tank:
```sql
SELECT get_tank_stats('tank-uuid');
```

## Row Level Security (RLS)

### Policies
- Users can only view their own tanks
- Users can only insert tanks for themselves
- Users can only update their own tanks
- Users can only delete their own tanks

## Migration Scripts

1. `update_tanks_schema_comprehensive.sql` - Complete schema update
2. `update_tank_model_fields.sql` - Field-specific updates
3. `create_tanks_table.sql` - Initial table creation

## Usage Examples

### Insert New Tank
```sql
INSERT INTO tanks (
  name, tank_shape, length, width, height, unit, volume,
  fish_selections, available_feeds, current_step
) VALUES (
  'My Aquarium', 'rectangle', 60, 30, 40, 'CM', 72.0,
  '{"Goldfish": 2, "Koi": 1}'::jsonb,
  '{"Pellets": 500.0, "Flakes": 300.0}'::jsonb,
  3
);
```

### Query Tank with Feed Duration
```sql
SELECT 
  name,
  volume,
  fish_selections,
  available_feeds,
  feed_duration_data
FROM tanks 
WHERE user_id = auth.uid();
```

### Update Feed Inventory
```sql
UPDATE tanks 
SET available_feeds = available_feeds || '{"Bloodworms": 200.0}'::jsonb
WHERE id = 'tank-uuid';
```

This schema provides comprehensive support for all features in the tank management system while maintaining data integrity and performance.
