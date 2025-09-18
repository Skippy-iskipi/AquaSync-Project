#!/usr/bin/env python3
"""
Script to populate fish_compatibility_matrix and fish_tankmate_recommendations tables
with real data from fish_species table instead of AI-generated content.
"""

import asyncio
import sys
import os
from typing import Dict, List, Tuple, Any
import json

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from supabase import create_client, Client
from app.conditional_compatibility import check_conditional_compatibility

# Supabase configuration
SUPABASE_URL = "https://your-project.supabase.co"  # Replace with your actual URL
SUPABASE_KEY = "your-anon-key"  # Replace with your actual key

def get_supabase_client() -> Client:
    """Get Supabase client"""
    return create_client(SUPABASE_URL, SUPABASE_KEY)

async def get_all_fish_species() -> List[Dict[str, Any]]:
    """Get all fish species from the database"""
    supabase = get_supabase_client()
    
    try:
        response = supabase.table('fish_species').select('*').execute()
        return response.data
    except Exception as e:
        print(f"Error fetching fish species: {e}")
        return []

def calculate_compatibility_matrix(fish_species: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Calculate compatibility matrix for all fish pairs"""
    compatibility_matrix = []
    total_pairs = len(fish_species) * (len(fish_species) - 1) // 2
    processed = 0
    
    print(f"Calculating compatibility for {total_pairs} fish pairs...")
    
    for i, fish1 in enumerate(fish_species):
        for j, fish2 in enumerate(fish_species):
            if i < j:  # Avoid duplicate pairs
                processed += 1
                if processed % 100 == 0:
                    print(f"Processed {processed}/{total_pairs} pairs...")
                
                try:
                    # Use conditional compatibility check directly
                    compatibility_level, reasons, conditions = check_conditional_compatibility(fish1, fish2)
                    
                    # Calculate compatibility score (0-100)
                    if compatibility_level == "compatible":
                        compatibility_score = 85.0
                    elif compatibility_level == "conditional":
                        compatibility_score = 60.0
                    else:  # incompatible
                        compatibility_score = 20.0
                    
                    # Calculate confidence score based on data completeness
                    confidence_score = calculate_confidence_score(fish1, fish2)
                    
                    matrix_entry = {
                        "fish1_name": fish1['common_name'],
                        "fish2_name": fish2['common_name'],
                        "compatibility_level": compatibility_level,
                        "is_compatible": compatibility_level in ["compatible", "conditional"],
                        "compatibility_reasons": reasons,
                        "conditions": conditions,
                        "compatibility_score": compatibility_score,
                        "confidence_score": confidence_score,
                        "generation_method": "enhanced_compatibility_system"
                    }
                    
                    compatibility_matrix.append(matrix_entry)
                    
                except Exception as e:
                    print(f"Error calculating compatibility for {fish1['common_name']} + {fish2['common_name']}: {e}")
                    # Add error entry
                    compatibility_matrix.append({
                        "fish1_name": fish1['common_name'],
                        "fish2_name": fish2['common_name'],
                        "compatibility_level": "unknown",
                        "is_compatible": False,
                        "compatibility_reasons": [f"Error calculating compatibility: {str(e)}"],
                        "conditions": [],
                        "compatibility_score": 0.0,
                        "confidence_score": 0.0,
                        "generation_method": "error"
                    })
    
    return compatibility_matrix

def calculate_confidence_score(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> float:
    """Calculate confidence score based on data completeness"""
    score = 0.0
    total_fields = 8
    
    # Check fish1 data completeness
    if fish1.get('temperament'): score += 1
    if fish1.get('water_type'): score += 1
    if fish1.get('max_size_(cm)'): score += 1
    if fish1.get('ph_range'): score += 1
    
    # Check fish2 data completeness
    if fish2.get('temperament'): score += 1
    if fish2.get('water_type'): score += 1
    if fish2.get('max_size_(cm)'): score += 1
    if fish2.get('ph_range'): score += 1
    
    return (score / total_fields) * 100.0

def generate_tankmate_recommendations(fish_species: List[Dict[str, Any]], compatibility_matrix: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Generate tankmate recommendations for each fish based on compatibility matrix"""
    tankmate_recommendations = []
    
    print(f"Generating tankmate recommendations for {len(fish_species)} fish...")
    
    for fish in fish_species:
        fish_name = fish['common_name']
        fully_compatible = []
        conditional = []
        incompatible = []
        
        # Find all compatibility entries for this fish
        for entry in compatibility_matrix:
            if entry['fish1_name'] == fish_name:
                other_fish = entry['fish2_name']
            elif entry['fish2_name'] == fish_name:
                other_fish = entry['fish1_name']
            else:
                continue
            
            if entry['compatibility_level'] == 'compatible':
                fully_compatible.append(other_fish)
            elif entry['compatibility_level'] == 'conditional':
                conditional.append({
                    'name': other_fish,
                    'conditions': entry['conditions']
                })
            else:  # incompatible
                incompatible.append(other_fish)
        
        # Sort lists alphabetically
        fully_compatible.sort()
        conditional.sort(key=lambda x: x['name'])
        incompatible.sort()
        
        # Calculate special requirements based on fish characteristics
        special_requirements = generate_special_requirements(fish)
        
        # Calculate care level and confidence
        care_level = fish.get('care_level', 'Intermediate')
        confidence_score = calculate_fish_confidence_score(fish)
        
        recommendation = {
            "fish_name": fish_name,
            "fully_compatible_tankmates": fully_compatible[:20],  # Limit to top 20
            "conditional_tankmates": conditional[:15],  # Limit to top 15
            "incompatible_tankmates": incompatible[:10],  # Limit to top 10
            "special_requirements": special_requirements,
            "care_level": care_level,
            "confidence_score": confidence_score,
            "total_fully_compatible": len(fully_compatible),
            "total_conditional": len(conditional),
            "total_incompatible": len(incompatible),
            "total_recommended": len(fully_compatible) + len(conditional)
        }
        
        tankmate_recommendations.append(recommendation)
    
    return tankmate_recommendations

def generate_special_requirements(fish: Dict[str, Any]) -> List[str]:
    """Generate special requirements based on fish characteristics"""
    requirements = []
    
    # Tank size requirements
    min_tank = fish.get('minimum_tank_size_(l)') or fish.get('minimum_tank_size_l')
    if min_tank and float(min_tank) > 200:
        requirements.append(f"Requires large tank (minimum {min_tank}L)")
    
    # Water type requirements
    water_type = fish.get('water_type', '').lower()
    if 'saltwater' in water_type:
        requirements.append("Requires saltwater setup")
    elif 'brackish' in water_type:
        requirements.append("Requires brackish water")
    
    # Temperament requirements
    temperament = fish.get('temperament', '').lower()
    if 'aggressive' in temperament:
        requirements.append("Aggressive fish - monitor tankmates carefully")
    elif 'territorial' in temperament:
        requirements.append("Territorial fish - provide adequate space and hiding spots")
    
    # Social behavior requirements
    social_behavior = fish.get('social_behavior', '').lower()
    if 'schooling' in social_behavior:
        min_school = fish.get('schooling_min_number', 6)
        requirements.append(f"Keep in groups of at least {min_school}")
    elif 'solitary' in social_behavior:
        requirements.append("Prefers to be kept alone")
    
    # Diet requirements
    diet = fish.get('diet', '').lower()
    if 'carnivore' in diet or 'piscivore' in diet:
        requirements.append("Carnivorous - provide appropriate live/frozen foods")
    elif 'herbivore' in diet:
        requirements.append("Herbivorous - provide plenty of plant matter")
    
    # Special care requirements
    care_level = fish.get('care_level', '').lower()
    if 'expert' in care_level:
        requirements.append("Expert level care required")
    elif 'beginner' in care_level:
        requirements.append("Suitable for beginners")
    
    return requirements

def calculate_fish_confidence_score(fish: Dict[str, Any]) -> float:
    """Calculate confidence score for fish data completeness"""
    score = 0.0
    total_fields = 10
    
    # Check important fields
    important_fields = [
        'temperament', 'water_type', 'max_size_(cm)', 'ph_range', 
        'temperature_range', 'social_behavior', 'diet', 'care_level',
        'minimum_tank_size_(l)', 'preferred_food'
    ]
    
    for field in important_fields:
        if fish.get(field):
            score += 1
    
    return (score / total_fields) * 100.0

async def populate_database():
    """Main function to populate the database with compatibility data"""
    print("Starting compatibility data population...")
    
    # Get all fish species
    fish_species = await get_all_fish_species()
    if not fish_species:
        print("No fish species found in database!")
        return
    
    print(f"Found {len(fish_species)} fish species")
    
    # Calculate compatibility matrix
    compatibility_matrix = calculate_compatibility_matrix(fish_species)
    print(f"Generated {len(compatibility_matrix)} compatibility entries")
    
    # Generate tankmate recommendations
    tankmate_recommendations = generate_tankmate_recommendations(fish_species, compatibility_matrix)
    print(f"Generated {len(tankmate_recommendations)} tankmate recommendation entries")
    
    # Upload to database
    supabase = get_supabase_client()
    
    try:
        # Clear existing data
        print("Clearing existing compatibility data...")
        supabase.table('fish_compatibility_matrix').delete().neq('fish1_name', '').execute()
        supabase.table('fish_tankmate_recommendations').delete().neq('fish_name', '').execute()
        
        # Insert compatibility matrix in batches
        print("Uploading compatibility matrix...")
        batch_size = 100
        for i in range(0, len(compatibility_matrix), batch_size):
            batch = compatibility_matrix[i:i + batch_size]
            supabase.table('fish_compatibility_matrix').insert(batch).execute()
            print(f"Uploaded batch {i//batch_size + 1}/{(len(compatibility_matrix) + batch_size - 1)//batch_size}")
        
        # Insert tankmate recommendations in batches
        print("Uploading tankmate recommendations...")
        for i in range(0, len(tankmate_recommendations), batch_size):
            batch = tankmate_recommendations[i:i + batch_size]
            supabase.table('fish_tankmate_recommendations').insert(batch).execute()
            print(f"Uploaded batch {i//batch_size + 1}/{(len(tankmate_recommendations) + batch_size - 1)//batch_size}")
        
        print("✅ Database population completed successfully!")
        print(f"📊 Statistics:")
        print(f"   - Fish species: {len(fish_species)}")
        print(f"   - Compatibility pairs: {len(compatibility_matrix)}")
        print(f"   - Tankmate recommendations: {len(tankmate_recommendations)}")
        
    except Exception as e:
        print(f"❌ Error uploading to database: {e}")

if __name__ == "__main__":
    # Update these with your actual Supabase credentials
    print("⚠️  Please update SUPABASE_URL and SUPABASE_KEY in this script before running!")
    print("   You can find these in your Supabase project settings.")
    
    # Uncomment the line below after updating the credentials
    # asyncio.run(populate_database())
