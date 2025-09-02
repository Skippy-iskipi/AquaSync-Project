#!/usr/bin/env python3
import sys
import os
sys.path.append('.')
from app.supabase_config import get_supabase_client

def main():
    db = get_supabase_client()
    
    # Check marine fish with 'solitary' behavior
    response = db.table('fish_species').select('common_name, social_behavior, water_type').eq('water_type', 'Saltwater').execute()
    marine_fish = response.data
    
    print('Marine fish marked as solitary:')
    solitary_count = 0
    for fish in marine_fish:
        behavior = str(fish.get('social_behavior', '')).lower()
        if 'solitary' in behavior:
            print(f'  - {fish.get("common_name")}: {fish.get("social_behavior")}')
            solitary_count += 1
    
    print(f'\nSolitary marine fish: {solitary_count}/{len(marine_fish)} ({solitary_count/len(marine_fish)*100:.1f}%)')
    print(f'Total marine fish in database: {len(marine_fish)}')
    
    # Common marine fish that should NOT be solitary
    should_not_be_solitary = [
        'Blue Tang', 'Yellow Tang', 'Clownfish', 'Coral Beauty', 
        'Six Line Wrasse', 'Foxface Rabbitfish', 'Cleaner Wrasse'
    ]
    
    print('\nChecking common reef fish that might be incorrectly marked as solitary:')
    for fish_name in should_not_be_solitary:
        fish_response = db.table('fish_species').select('common_name, social_behavior').ilike('common_name', fish_name).execute()
        if fish_response.data:
            fish_data = fish_response.data[0]
            behavior = str(fish_data.get('social_behavior', '')).lower()
            if 'solitary' in behavior:
                print(f'  ❌ {fish_data.get("common_name")}: Incorrectly marked as "{fish_data.get("social_behavior")}"')
            else:
                print(f'  ✅ {fish_data.get("common_name")}: Correctly marked as "{fish_data.get("social_behavior")}"')
        else:
            print(f'  ? {fish_name}: Not found in database')

if __name__ == "__main__":
    main()
