# Tanks Table Documentation

## Overview
The `tanks` table is a comprehensive data structure that stores all information related to tank management, including fish selections, feed inventory, compatibility analysis, and feeding recommendations.

## Table Structure

### Core Tank Information
| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | Primary key | `gen_random_uuid()` |
| `user_id` | UUID | Foreign key to auth.users | `ON DELETE CASCADE` |
| `tank_name` | TEXT | Name of the tank | `NOT NULL` |
| `tank_shape` | TEXT | Tank shape type | `CHECK (tank_shape IN ('rectangle', 'bowl', 'cylinder'))` |
| `length` | DECIMAL(10,2) | Tank length | `NOT NULL, CHECK (length > 0)` |
| `width` | DECIMAL(10,2) | Tank width | `NOT NULL, CHECK (width > 0)` |
| `height` | DECIMAL(10,2) | Tank height | `NOT NULL, CHECK (height > 0)` |
| `unit` | TEXT | Measurement unit | `CHECK (unit IN ('CM', 'IN'))` |
| `tank_volume` | DECIMAL(10,2) | Calculated volume in liters | `NOT NULL, CHECK (tank_volume > 0)` |

### Fish and Feeding Data
| Column | Type | Description | JSONB Structure |
|--------|------|-------------|-----------------|
| `selected_fish` | JSONB | Fish species and quantities | `{"Goldfish": 2, "Koi": 1}` |
| `fish_feeding_data` | JSONB | Per fish feeding information | See detailed structure below |

### Feed Inventory Data
| Column | Type | Description | JSONB Structure |
|--------|------|-------------|-----------------|
| `feed_inventory` | JSONB | Feed inventory with consumption data | See detailed structure below |

### Analysis Data
| Column | Type | Description | JSONB Structure |
|--------|------|-------------|-----------------|
| `compatibility_analysis` | JSONB | Fish compatibility and tank size analysis | See detailed structure below |
| `feeding_recommendations` | JSONB | AI-generated feeding recommendations | See detailed structure below |
| `feed_recommendations` | JSONB | Feed type recommendations | See detailed structure below |

### Timestamps
| Column | Type | Description |
|--------|------|-------------|
| `date_created` | TIMESTAMP WITH TIME ZONE | Creation timestamp |
| `last_updated` | TIMESTAMP WITH TIME ZONE | Last update timestamp |
| `created_at` | TIMESTAMP WITH TIME ZONE | Creation timestamp (legacy) |

## Detailed JSONB Structures

### selected_fish
```json
{
  "Goldfish": 2,
  "Koi": 1,
  "Betta": 3,
  "Neon Tetra": 10
}
```

### fish_feeding_data
```json
{
  "Goldfish": {
    "portion_per_feeding": 5.0,
    "feeding_frequency": 2,
    "preferred_food": "pellets, flakes",
    "daily_consumption": 10.0
  },
  "Koi": {
    "portion_per_feeding": 8.0,
    "feeding_frequency": 2,
    "preferred_food": "pellets, vegetables",
    "daily_consumption": 16.0
  },
  "Betta": {
    "portion_per_feeding": 2.0,
    "feeding_frequency": 1,
    "preferred_food": "pellets, bloodworms",
    "daily_consumption": 2.0
  }
}
```

### feed_inventory
```json
{
  "Pellets": {
    "quantity_grams": 500.0,
    "daily_consumption": 16.67,
    "days_remaining": 30,
    "is_low_stock": false,
    "is_critical": false,
    "consumption_by_fish": {
      "Goldfish": 10.0,
      "Koi": 6.67
    }
  },
  "Flakes": {
    "quantity_grams": 300.0,
    "daily_consumption": 20.0,
    "days_remaining": 15,
    "is_low_stock": true,
    "is_critical": false,
    "consumption_by_fish": {
      "Betta": 2.0,
      "Neon Tetra": 18.0
    }
  },
  "Bloodworms": {
    "quantity_grams": 100.0,
    "daily_consumption": 5.0,
    "days_remaining": 20,
    "is_low_stock": false,
    "is_critical": false,
    "consumption_by_fish": {
      "Betta": 5.0
    }
  }
}
```

### compatibility_analysis
```json
{
  "has_incompatible_pairs": false,
  "has_conditional_pairs": true,
  "incompatible_pairs": [],
  "conditional_pairs": [
    {
      "pair": ["Goldfish", "Koi"],
      "reasons": ["Similar dietary requirements", "Both are coldwater fish"],
      "type": "conditional"
    },
    {
      "pair": ["Betta", "Neon Tetra"],
      "reasons": ["Betta may be aggressive towards small fish"],
      "type": "conditional"
    }
  ],
  "tank_size_warnings": {
    "Goldfish": "Goldfish is suitable for this tank size.",
    "Koi": "Koi needs more swimming space than this tank provides. Consider upgrading to a larger tank.",
    "Betta": "Betta is suitable for this tank size.",
    "Neon Tetra": "Neon Tetra is suitable for this tank size."
  }
}
```

### feeding_recommendations
```json
{
  "feeding_schedule": "2 times daily",
  "portion_per_feeding": "5g per fish",
  "feeding_notes": "Feed in morning and evening. Reduce portions if fish show signs of overfeeding.",
  "total_daily_food": "30g",
  "feeding_times": ["08:00", "18:00"],
  "special_considerations": [
    "Goldfish and Koi are coldwater fish - feed at room temperature",
    "Betta prefers floating pellets",
    "Neon Tetra should be fed small portions due to their size"
  ]
}
```

### feed_recommendations
```json
{
  "recommended": [
    "Pellets",
    "Flakes", 
    "Spirulina",
    "Vegetable-based foods"
  ],
  "incompatible": [
    "Bloodworms",
    "Live Food"
  ],
  "reasoning": {
    "Pellets": "Suitable for omnivorous fish like Goldfish and Koi",
    "Flakes": "Good for small fish like Neon Tetra and Betta",
    "Spirulina": "Excellent for herbivorous fish and provides essential nutrients",
    "Bloodworms": "Not suitable for herbivorous fish, may cause digestive issues",
    "Live Food": "Risk of introducing diseases, not recommended for community tanks"
  },
  "feeding_priority": {
    "Goldfish": ["Pellets", "Vegetable-based foods"],
    "Koi": ["Pellets", "Vegetable-based foods"],
    "Betta": ["Pellets", "Flakes"],
    "Neon Tetra": ["Flakes", "Small pellets"]
  }
}
```

## Sample Complete Tank Record

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "user-uuid-here",
  "tank_name": "My Community Tank",
  "tank_shape": "rectangle",
  "length": 60.0,
  "width": 30.0,
  "height": 40.0,
  "unit": "CM",
  "tank_volume": 72.0,
  "selected_fish": {
    "Goldfish": 2,
    "Koi": 1,
    "Betta": 1,
    "Neon Tetra": 10
  },
  "fish_feeding_data": {
    "Goldfish": {
      "portion_per_feeding": 5.0,
      "feeding_frequency": 2,
      "preferred_food": "pellets, flakes",
      "daily_consumption": 10.0
    },
    "Koi": {
      "portion_per_feeding": 8.0,
      "feeding_frequency": 2,
      "preferred_food": "pellets, vegetables",
      "daily_consumption": 16.0
    },
    "Betta": {
      "portion_per_feeding": 2.0,
      "feeding_frequency": 1,
      "preferred_food": "pellets, bloodworms",
      "daily_consumption": 2.0
    },
    "Neon Tetra": {
      "portion_per_feeding": 0.5,
      "feeding_frequency": 2,
      "preferred_food": "flakes, small pellets",
      "daily_consumption": 1.0
    }
  },
  "feed_inventory": {
    "Pellets": {
      "quantity_grams": 500.0,
      "daily_consumption": 16.67,
      "days_remaining": 30,
      "is_low_stock": false,
      "is_critical": false,
      "consumption_by_fish": {
        "Goldfish": 10.0,
        "Koi": 6.67
      }
    },
    "Flakes": {
      "quantity_grams": 300.0,
      "daily_consumption": 20.0,
      "days_remaining": 15,
      "is_low_stock": true,
      "is_critical": false,
      "consumption_by_fish": {
        "Betta": 2.0,
        "Neon Tetra": 18.0
      }
    }
  },
  "compatibility_analysis": {
    "has_incompatible_pairs": false,
    "has_conditional_pairs": true,
    "incompatible_pairs": [],
    "conditional_pairs": [
      {
        "pair": ["Goldfish", "Koi"],
        "reasons": ["Similar dietary requirements"],
        "type": "conditional"
      }
    ],
    "tank_size_warnings": {
      "Goldfish": "Goldfish is suitable for this tank size.",
      "Koi": "Koi needs more swimming space than this tank provides."
    }
  },
  "feeding_recommendations": {
    "feeding_schedule": "2 times daily",
    "portion_per_feeding": "5g per fish",
    "feeding_notes": "Feed in morning and evening",
    "total_daily_food": "30g"
  },
  "feed_recommendations": {
    "recommended": ["Pellets", "Flakes"],
    "incompatible": ["Bloodworms"],
    "reasoning": {
      "Pellets": "Suitable for omnivorous fish",
      "Bloodworms": "Not suitable for herbivorous fish"
    }
  },
  "date_created": "2024-01-15T10:30:00Z",
  "last_updated": "2024-01-15T14:45:00Z"
}
```

## Helper Functions

### get_tank_fish_count(tank_id)
Returns the total number of fish in a tank.
```sql
SELECT get_tank_fish_count('tank-uuid');
-- Returns: 14 (2 Goldfish + 1 Koi + 1 Betta + 10 Neon Tetra)
```

### get_tank_feed_duration(tank_id, feed_name)
Returns the days remaining for a specific feed type.
```sql
SELECT get_tank_feed_duration('tank-uuid', 'Pellets');
-- Returns: 30
```

### get_tank_compatibility_status(tank_id)
Returns the overall compatibility status.
```sql
SELECT get_tank_compatibility_status('tank-uuid');
-- Returns: 'Conditional' (has conditional pairs)
```

## Usage Examples

### Insert New Tank
```sql
INSERT INTO tanks (
  tank_name, tank_shape, length, width, height, unit, tank_volume,
  selected_fish, fish_feeding_data, feed_inventory, compatibility_analysis
) VALUES (
  'My Aquarium', 'rectangle', 60, 30, 40, 'CM', 72.0,
  '{"Goldfish": 2, "Koi": 1}'::jsonb,
  '{"Goldfish": {"portion_per_feeding": 5.0, "feeding_frequency": 2, "preferred_food": "pellets", "daily_consumption": 10.0}}'::jsonb,
  '{"Pellets": {"quantity_grams": 500.0, "daily_consumption": 16.67, "days_remaining": 30, "is_low_stock": false, "is_critical": false, "consumption_by_fish": {"Goldfish": 10.0, "Koi": 6.67}}}'::jsonb,
  '{"has_incompatible_pairs": false, "has_conditional_pairs": true, "incompatible_pairs": [], "conditional_pairs": [{"pair": ["Goldfish", "Koi"], "reasons": ["Similar dietary requirements"], "type": "conditional"}]}'::jsonb
);
```

### Query Tank with Feed Duration
```sql
SELECT 
  tank_name,
  tank_volume,
  selected_fish,
  feed_inventory,
  compatibility_analysis
FROM tanks 
WHERE user_id = auth.uid();
```

### Update Feed Inventory
```sql
UPDATE tanks 
SET feed_inventory = feed_inventory || '{"Bloodworms": {"quantity_grams": 200.0, "daily_consumption": 5.0, "days_remaining": 40, "is_low_stock": false, "is_critical": false, "consumption_by_fish": {"Betta": 5.0}}}'::jsonb
WHERE id = 'tank-uuid';
```

This comprehensive table structure provides all the necessary data for the tank management system while maintaining data integrity and performance.
