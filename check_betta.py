#!/usr/bin/env python3
import sys
import os
sys.path.append('.')
from app.supabase_config import get_supabase_client

def main():
    db = get_supabase_client()
    response = db.table('fish_species').select('*').ilike('common_name', 'betta').execute()
    
    if response.data:
        betta = response.data[0]
        print('Betta data:')
        print(f'  common_name: {betta.get("common_name")}')
        print(f'  temperament: {betta.get("temperament")}')
        print(f'  social_behavior: {betta.get("social_behavior")}')
        print(f'  water_type: {betta.get("water_type")}')
        print(f'  max_size_(cm): {betta.get("max_size_(cm)")}')
        
        # Test with a few of the fish from the problematic list
        problematic_fish = ["Angelfish", "Tiger Barb", "Rainbow Shark"]
        
        from app.conditional_compatibility import check_conditional_compatibility
        
        print('\nCompatibility tests:')
        for fish_name in problematic_fish:
            fish_response = db.table('fish_species').select('*').ilike('common_name', fish_name).execute()
            if fish_response.data:
                other_fish = fish_response.data[0]
                result = check_conditional_compatibility(betta, other_fish)
                print(f'  Betta vs {fish_name}: {result[0]}')
                if result[1]:
                    print(f'    Reasons: {result[1]}')
                if result[2]:
                    print(f'    Conditions: {result[2]}')
            else:
                print(f'  {fish_name}: Not found in database')
    else:
        print('No Betta found in database')

if __name__ == "__main__":
    main()
