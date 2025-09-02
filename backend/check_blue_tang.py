#!/usr/bin/env python3
import sys
import os
sys.path.append('.')
from app.supabase_config import get_supabase_client
from app.conditional_compatibility import check_conditional_compatibility

def main():
    db = get_supabase_client()
    
    # Get Blue Tang data
    blue_tang_response = db.table('fish_species').select('*').ilike('common_name', 'blue tang').execute()
    clownfish_response = db.table('fish_species').select('*').ilike('common_name', 'clownfish').execute()
    
    if blue_tang_response.data and clownfish_response.data:
        blue_tang = blue_tang_response.data[0]
        clownfish = clownfish_response.data[0]
        
        print('=== BLUE TANG DATA ===')
        print(f'Common name: {blue_tang.get("common_name")}')
        print(f'Temperament: {blue_tang.get("temperament")}')
        print(f'Social behavior: {blue_tang.get("social_behavior")}')
        print(f'Water type: {blue_tang.get("water_type")}')
        max_size_key = 'max_size_(cm)'
        print(f'Max size: {blue_tang.get(max_size_key)} cm')
        print(f'Tank level: {blue_tang.get("tank_level")}')
        print(f'Diet: {blue_tang.get("diet")}')
        
        print('\n=== CLOWNFISH DATA ===')
        print(f'Common name: {clownfish.get("common_name")}')
        print(f'Temperament: {clownfish.get("temperament")}')
        print(f'Social behavior: {clownfish.get("social_behavior")}')
        print(f'Water type: {clownfish.get("water_type")}')
        print(f'Max size: {clownfish.get(max_size_key)} cm')
        print(f'Tank level: {clownfish.get("tank_level")}')
        print(f'Diet: {clownfish.get("diet")}')
        
        print('\n=== COMPATIBILITY TEST ===')
        result = check_conditional_compatibility(blue_tang, clownfish)
        print(f'Compatibility: {result[0]}')
        print(f'Reasons: {result[1]}')
        print(f'Conditions: {result[2]}')
        
        # Check Blue Tang's tankmate recommendations
        print('\n=== BLUE TANG TANKMATE RECOMMENDATIONS ===')
        tankmate_response = db.table('fish_tankmate_recommendations').select('*').ilike('fish_name', 'blue tang').execute()
        if tankmate_response.data:
            recommendations = tankmate_response.data[0]
            print(f'Total compatible: {recommendations["total_compatible"]}')
            print(f'Compatible tankmates: {recommendations["compatible_tankmates"]}')
        else:
            print('No tankmate recommendations found')
            
        # Test with a few other marine fish
        print('\n=== TESTING WITH OTHER MARINE FISH ===')
        marine_fish = ['Yellow Tang', 'Foxface Rabbitfish', 'Six Line Wrasse']
        
        for fish_name in marine_fish:
            test_response = db.table('fish_species').select('*').ilike('common_name', fish_name).execute()
            if test_response.data:
                test_fish = test_response.data[0]
                test_result = check_conditional_compatibility(blue_tang, test_fish)
                print(f'{fish_name}: {test_result[0]}')
                if test_result[1]:
                    print(f'  Reasons: {test_result[1][:2]}')  # Show first 2 reasons
            else:
                print(f'{fish_name}: Not found in database')
                
    else:
        if not blue_tang_response.data:
            print('Blue Tang not found in database')
        if not clownfish_response.data:
            print('Clownfish not found in database')

if __name__ == "__main__":
    main()
