# Simplified Tank Database Schema

## Overview
This document describes the simplified database schema for the tank management system, containing only the essential data that's actually saved from the `add_edit_tank.dart` form.

## Table: `tanks`

### Core Tank Information
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `id` | UUID | Primary key | `gen_random_uuid()` |
| `user_id` | UUID | Foreign key to auth.users | `auth.uid()` |
| `tank_name` | TEXT | Name of the tank | `"My Aquarium"` |
| `tank_shape` | TEXT | Tank shape type | `"rectangle"`, `"bowl"`, `"cylinder"` |
| `length` | DECIMAL(10,2) | Tank length | `60.00` |
| `width` | DECIMAL(10,2) | Tank width | `30.00` |
| `height` | DECIMAL(10,2) | Tank height | `40.00` |
| `unit` | TEXT | Measurement unit | `"CM"`, `"IN"` |
| `calculated_volume` | DECIMAL(10,2) | Calculated volume in liters | `72.00` |

### Fish and Feed Data
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `selected_fish` | JSONB | Fish species and quantities | `{"Goldfish": 2, "Koi": 1}` |
| `feed_types` | JSONB | Feed types and quantities in grams | `{"Pellets": 500.0, "Flakes": 300.0}` |
| `available_feed_qty` | JSONB | Available feed quantities (same as feed_types) | `{"Pellets": 500.0, "Flakes": 300.0}` |
| `fish_feeding_data` | JSONB | Per fish feeding information | See structure below |
| `feed_duration_data` | JSONB | Feed duration calculations | See structure below |
| `compatibility_results` | JSONB | Fish compatibility analysis | See structure below |
| `tank_size_notice` | JSONB | Tank size warnings for fish | See structure below |

### Timestamps
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `date_created` | TIMESTAMP WITH TIME ZONE | Creation timestamp | `2024-01-15 10:30:00+00` |
| `last_updated` | TIMESTAMP WITH TIME ZONE | Last update timestamp | `2024-01-15 14:45:00+00` |

## JSONB Field Structures

### selected_fish
```json
{
  "Goldfish": 2,
  "Koi": 1,
  "Betta": 3
}
```

### feed_types / available_feed_qty
```json
{
  "Pellets": 500.0,
  "Flakes": 300.0,
  "Bloodworms": 100.0
}
```

### fish_feeding_data
```json
{
  "Goldfish": {
    "portion_per_feeding": 5.0,
    "feeding_frequency": 2,
    "daily_consumption": 10.0,
    "preferred_food": "pellets, flakes"
  },
  "Koi": {
    "portion_per_feeding": 8.0,
    "feeding_frequency": 2,
    "daily_consumption": 16.0,
    "preferred_food": "pellets, vegetables"
  }
}
```

### feed_duration_data
```json
{
  "Pellets": {
    "days_remaining": 30,
    "daily_consumption": 16.67,
    "is_low_stock": false,
    "is_critical": false
  },
  "Flakes": {
    "days_remaining": 15,
    "daily_consumption": 20.0,
    "is_low_stock": true,
    "is_critical": false
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

### tank_size_notice
```json
{
  "Goldfish": "Goldfish is too large for a bowl tank. Bowl tanks are small and only suitable for tiny fish like bettas or small tetras.",
  "Koi": "Koi needs more swimming space than a cylinder tank provides. Cylinder tanks are tall but narrow, limiting swimming space."
}
```

## Data Mapping from add_edit_tank.dart

### Tank Setup Step
- `tank_name` ← `_nameController.text`
- `tank_shape` ← `_selectedShape`
- `length` ← `_lengthController.text`
- `width` ← `_widthController.text`
- `height` ← `_heightController.text`
- `unit` ← `_selectedUnit`
- `calculated_volume` ← `_calculatedVolume`

### Fish Selection Step
- `selected_fish` ← `_fishSelections`
- `fish_feeding_data` ← Calculated from fish species data
- `tank_size_notice` ← `_tankShapeWarnings`

### Feed Inventory Step
- `feed_types` ← `_availableFeeds`
- `available_feed_qty` ← `_availableFeeds` (same data)
- `feed_duration_data` ← `_feedDurationData`

### Summary Step
- `compatibility_results` ← `_compatibilityResults`

## Sample Data Structure

### Complete Tank Record
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "user-uuid",
  "tank_name": "My Aquarium",
  "tank_shape": "rectangle",
  "length": 60.0,
  "width": 30.0,
  "height": 40.0,
  "unit": "CM",
  "calculated_volume": 72.0,
  "selected_fish": {
    "Goldfish": 2,
    "Koi": 1
  },
  "feed_types": {
    "Pellets": 500.0,
    "Flakes": 300.0
  },
  "available_feed_qty": {
    "Pellets": 500.0,
    "Flakes": 300.0
  },
  "fish_feeding_data": {
    "Goldfish": {
      "portion_per_feeding": 5.0,
      "feeding_frequency": 2,
      "daily_consumption": 10.0,
      "preferred_food": "pellets, flakes"
    },
    "Koi": {
      "portion_per_feeding": 8.0,
      "feeding_frequency": 2,
      "daily_consumption": 16.0,
      "preferred_food": "pellets, vegetables"
    }
  },
  "feed_duration_data": {
    "Pellets": {
      "days_remaining": 30,
      "daily_consumption": 16.67,
      "is_low_stock": false,
      "is_critical": false
    },
    "Flakes": {
      "days_remaining": 15,
      "daily_consumption": 20.0,
      "is_low_stock": true,
      "is_critical": false
    }
  },
  "compatibility_results": {
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
  },
  "tank_size_notice": {
    "Goldfish": "Goldfish is suitable for this tank size.",
    "Koi": "Koi needs more swimming space than this tank provides."
  },
  "date_created": "2024-01-15T10:30:00Z",
  "last_updated": "2024-01-15T14:45:00Z"
}
```

## Usage Examples

### Insert New Tank
```sql
INSERT INTO tanks (
  tank_name, tank_shape, length, width, height, unit, calculated_volume,
  selected_fish, feed_types, available_feed_qty, fish_feeding_data,
  feed_duration_data, compatibility_results, tank_size_notice
) VALUES (
  'My Aquarium', 'rectangle', 60, 30, 40, 'CM', 72.0,
  '{"Goldfish": 2, "Koi": 1}'::jsonb,
  '{"Pellets": 500.0, "Flakes": 300.0}'::jsonb,
  '{"Pellets": 500.0, "Flakes": 300.0}'::jsonb,
  '{"Goldfish": {"portion_per_feeding": 5.0, "feeding_frequency": 2, "daily_consumption": 10.0, "preferred_food": "pellets, flakes"}}'::jsonb,
  '{"Pellets": {"days_remaining": 30, "daily_consumption": 16.67, "is_low_stock": false, "is_critical": false}}'::jsonb,
  '{"has_incompatible_pairs": false, "has_conditional_pairs": true}'::jsonb,
  '{"Goldfish": "Suitable for this tank size"}'::jsonb
);
```

### Query Tank Data
```sql
SELECT 
  tank_name,
  tank_shape,
  calculated_volume,
  selected_fish,
  feed_types,
  fish_feeding_data,
  feed_duration_data
FROM tanks 
WHERE user_id = auth.uid();
```

### Update Feed Quantities
```sql
UPDATE tanks 
SET 
  feed_types = feed_types || '{"Bloodworms": 200.0}'::jsonb,
  available_feed_qty = available_feed_qty || '{"Bloodworms": 200.0}'::jsonb
WHERE id = 'tank-uuid';
```

## Migration Instructions

1. **Run the migration script:**
   ```sql
   -- Execute migrate_to_simplified_schema.sql
   ```

2. **Verify the schema:**
   ```sql
   SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'tanks';
   ```

3. **Test with sample data:**
   ```sql
   INSERT INTO tanks (tank_name, tank_shape, length, width, height, unit, calculated_volume, selected_fish, feed_types) 
   VALUES ('Test Tank', 'rectangle', 60, 30, 40, 'CM', 72.0, '{"Goldfish": 2}'::jsonb, '{"Pellets": 500.0}'::jsonb);
   ```

This simplified schema contains only the essential data that's actually used in the tank management system, making it easier to maintain and understand.
