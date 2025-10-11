#!/usr/bin/env python3
"""
Unified Compatibility Data Population Script
This script populates BOTH fish_compatibility_matrix AND fish_tankmate_recommendations
using the enhanced compatibility system.
"""

import asyncio
import sys
import os
from typing import Dict, List, Any
import io

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.enhanced_compatibility_integration import check_enhanced_fish_compatibility
from supabase import create_client, Client

# Configuration
SUPABASE_URL = "https://rdiwfttfxxpenrcxyfuv.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkaXdmdHRmeHhwZW5yY3h5ZnV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNDYzNTMsImV4cCI6MjA2NTcyMjM1M30.yYSE_9oREqsWhcL3O1isDmBLkszqrmzAOYHSGQHds8A"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkaXdmdHRmeHhwZW5yY3h5ZnV2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDE0NjM1MywiZXhwIjoyMDY1NzIyMzUzfQ.s3bFGhsUl9YR5AEE355mCe_kFokgl0lQxM_vir9QIfU"

def get_supabase_client(use_service_key: bool = False) -> Client:
    """Get Supabase client with credentials"""
    supabase_url = os.getenv('SUPABASE_URL', SUPABASE_URL)
    
    if use_service_key:
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY', SUPABASE_SERVICE_KEY)
    else:
        supabase_key = os.getenv('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY)
    
    return create_client(supabase_url, supabase_key)

async def get_all_fish_species() -> List[Dict[str, Any]]:
    """Get all fish species from database"""
    db = get_supabase_client()
    
    try:
        response = db.table('fish_species').select('*').execute()
        return response.data
    except Exception as e:
        print(f"Error fetching fish species: {e}")
        return []

def calculate_compatibility_for_pair(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate compatibility for a single fish pair"""
    try:
        # Use enhanced compatibility system
        compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
        
        # Calculate scores (scale to 0-9.99 range)
        if compatibility_level == "compatible":
            compatibility_score = 8.5
        elif compatibility_level == "conditional":
            compatibility_score = 6.0
        else:
            compatibility_score = 2.0
        
        # Calculate confidence score
        raw_confidence = calculate_confidence_score(fish1, fish2)
        confidence_score = min(raw_confidence / 10.0, 9.99)
        
        is_compatible = compatibility_level in ["compatible", "conditional"]
        
        result = {
            "fish1_name": fish1['common_name'],
            "fish2_name": fish2['common_name'],
            "compatibility_level": compatibility_level,
            "is_compatible": is_compatible,
            "compatibility_reasons": reasons,
            "conditions": conditions,
            "compatibility_score": round(compatibility_score, 2),
            "confidence_score": round(confidence_score, 2),
            "generation_method": "enhanced_compatibility_system"
        }
        return result
        
    except Exception as e:
        print(f"Error calculating compatibility for {fish1['common_name']} + {fish2['common_name']}: {e}")
        return {
            "fish1_name": fish1['common_name'],
            "fish2_name": fish2['common_name'],
            "compatibility_level": "unknown",
            "is_compatible": False,
            "compatibility_reasons": [f"Error: {str(e)}"],
            "conditions": [],
            "compatibility_score": 0.0,
            "confidence_score": 0.0,
            "generation_method": "error"
        }

def calculate_confidence_score(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> float:
    """Calculate confidence score based on data completeness"""
    score = 0.0
    total_fields = 8
    
    # Check fish1 data
    if fish1.get('temperament'): score += 1
    if fish1.get('water_type'): score += 1
    if fish1.get('max_size_(cm)'): score += 1
    if fish1.get('ph_range'): score += 1
    
    # Check fish2 data
    if fish2.get('temperament'): score += 1
    if fish2.get('water_type'): score += 1
    if fish2.get('max_size_(cm)'): score += 1
    if fish2.get('ph_range'): score += 1
    
    return (score / total_fields) * 100.0

def generate_tankmate_recommendations(fish: Dict[str, Any], compatibility_matrix: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Generate tankmate recommendations for a single fish"""
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
        else:
            incompatible.append(other_fish)
    
    # Sort lists
    fully_compatible.sort()
    conditional.sort(key=lambda x: x['name'])
    incompatible.sort()
    
    # Generate special requirements
    special_requirements = generate_special_requirements(fish)
    
    # Calculate fish confidence score
    fish_confidence = calculate_fish_confidence_score(fish)
    
    result = {
        "fish_name": fish_name,
        "fully_compatible_tankmates": fully_compatible[:20],
        "conditional_tankmates": conditional[:15],
        "incompatible_tankmates": incompatible[:10],
        "special_requirements": special_requirements,
        "care_level": fish.get('care_level', 'Intermediate'),
        "confidence_score": round(min(fish_confidence, 9.99), 2),
        "total_fully_compatible": min(len(fully_compatible), 99),
        "total_conditional": min(len(conditional), 99),
        "total_incompatible": min(len(incompatible), 99),
        "total_recommended": min(len(fully_compatible) + len(conditional), 99)
    }
    return result

def generate_special_requirements(fish: Dict[str, Any]) -> List[str]:
    """Generate special requirements based on fish characteristics"""
    requirements = []
    
    # Tank size
    min_tank = fish.get('minimum_tank_size_(l)') or fish.get('minimum_tank_size_l')
    if min_tank and float(min_tank) > 200:
        requirements.append(f"Requires large tank (minimum {min_tank}L)")
    
    # Water type
    water_type = fish.get('water_type', '').lower()
    if 'saltwater' in water_type:
        requirements.append("Requires saltwater setup")
    elif 'brackish' in water_type:
        requirements.append("Requires brackish water")
    
    # Temperament
    temperament = fish.get('temperament', '').lower()
    if 'aggressive' in temperament:
        requirements.append("Aggressive fish - monitor tankmates carefully")
    elif 'territorial' in temperament:
        requirements.append("Territorial fish - provide adequate space and hiding spots")
    
    # Social behavior
    social_behavior = fish.get('social_behavior', '').lower()
    if 'schooling' in social_behavior:
        min_school = fish.get('schooling_min_number', 6)
        requirements.append(f"Keep in groups of at least {min_school}")
    elif 'solitary' in social_behavior:
        requirements.append("Prefers to be kept alone")
    
    return requirements

def calculate_fish_confidence_score(fish: Dict[str, Any]) -> float:
    """Calculate confidence score for fish data completeness"""
    score = 0.0
    total_fields = 10
    
    important_fields = [
        'temperament', 'water_type', 'max_size_(cm)', 'ph_range', 
        'temperature_range', 'social_behavior', 'diet', 'care_level',
        'minimum_tank_size_(l)', 'preferred_food'
    ]
    
    for field in important_fields:
        if fish.get(field):
            score += 1
    
    result = (score / total_fields) * 10.0
    return min(result, 9.99)

async def populate_data():
    """Main function to populate compatibility data"""
    print("=" * 60)
    print("  COMPATIBILITY DATA POPULATION SCRIPT")
    print("=" * 60)
    print()
    print("🚀 Starting compatibility data population...")
    print()
    
    # Get all fish species
    fish_species = await get_all_fish_species()
    if not fish_species:
        print("❌ No fish species found in database!")
        return
    
    print(f"📊 Found {len(fish_species)} fish species")
    print()
    
    # Calculate compatibility matrix
    print("🔄 Step 1: Calculating compatibility matrix...")
    compatibility_matrix = []
    total_pairs = len(fish_species) * (len(fish_species) - 1) // 2
    processed = 0
    
    for i, fish1 in enumerate(fish_species):
        for j, fish2 in enumerate(fish_species):
            if i < j:
                processed += 1
                if processed % 500 == 0 or processed == 1:
                    print(f"   Progress: {processed}/{total_pairs} pairs ({processed*100//total_pairs}%)")
                
                compatibility_entry = calculate_compatibility_for_pair(fish1, fish2)
                compatibility_matrix.append(compatibility_entry)
    
    print(f"✅ Generated {len(compatibility_matrix)} compatibility entries")
    print()
    
    # Generate tankmate recommendations
    print("🔄 Step 2: Generating tankmate recommendations...")
    tankmate_recommendations = []
    
    for idx, fish in enumerate(fish_species, 1):
        if idx % 20 == 0 or idx == 1:
            print(f"   Progress: {idx}/{len(fish_species)} fish ({idx*100//len(fish_species)}%)")
        
        recommendation = generate_tankmate_recommendations(fish, compatibility_matrix)
        tankmate_recommendations.append(recommendation)
    
    print(f"✅ Generated {len(tankmate_recommendations)} tankmate recommendations")
    print()
    
    # Upload to database
    print("🔄 Step 3: Uploading to database...")
    db = get_supabase_client(use_service_key=True)
    
    try:
        # Clear existing data
        print("   Clearing existing data...")
        db.table('fish_compatibility_matrix').delete().neq('fish1_name', '').execute()
        db.table('fish_tankmate_recommendations').delete().neq('fish_name', '').execute()
        print("   ✅ Existing data cleared")
        print()
        
        # Insert compatibility matrix
        print("   Uploading compatibility matrix...")
        batch_size = 100
        total_batches = (len(compatibility_matrix) + batch_size - 1) // batch_size
        
        for i in range(0, len(compatibility_matrix), batch_size):
            batch = compatibility_matrix[i:i + batch_size]
            batch_num = i // batch_size + 1
            
            db.table('fish_compatibility_matrix').insert(batch).execute()
            if batch_num % 10 == 0 or batch_num == total_batches:
                print(f"     Batch {batch_num}/{total_batches} uploaded")
        
        print(f"   ✅ Uploaded {len(compatibility_matrix)} compatibility pairs")
        print()
        
        # Insert tankmate recommendations
        print("   Uploading tankmate recommendations...")
        batch_size = 50
        total_batches = (len(tankmate_recommendations) + batch_size - 1) // batch_size
        
        for i in range(0, len(tankmate_recommendations), batch_size):
            batch = tankmate_recommendations[i:i + batch_size]
            batch_num = i // batch_size + 1
            
            db.table('fish_tankmate_recommendations').insert(batch).execute()
            if batch_num % 5 == 0 or batch_num == total_batches:
                print(f"     Batch {batch_num}/{total_batches} uploaded")
        
        print(f"   ✅ Uploaded {len(tankmate_recommendations)} tankmate recommendations")
        print()
        
        print("=" * 60)
        print("🎉 DATABASE POPULATION COMPLETED SUCCESSFULLY!")
        print("=" * 60)
        print()
        print("📈 Final Statistics:")
        print(f"   • Fish species processed: {len(fish_species)}")
        print(f"   • Compatibility pairs: {len(compatibility_matrix)}")
        print(f"   • Tankmate recommendations: {len(tankmate_recommendations)}")
        print()
        
        # Show sample results
        if compatibility_matrix:
            sample = compatibility_matrix[0]
            print(f"📋 Sample Compatibility:")
            print(f"   {sample['fish1_name']} + {sample['fish2_name']}")
            print(f"   Level: {sample['compatibility_level']}")
            print(f"   Score: {sample['compatibility_score']}")
        
        if tankmate_recommendations:
            sample = tankmate_recommendations[0]
            print(f"\n📋 Sample Tankmate Recommendations:")
            print(f"   Fish: {sample['fish_name']}")
            print(f"   Fully compatible: {sample['total_fully_compatible']}")
            print(f"   Conditional: {sample['total_conditional']}")
            print(f"   Care level: {sample['care_level']}")
        
        print()
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ Error uploading to database: {e}")
        print(f"   Error details: {type(e).__name__}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(populate_data())

