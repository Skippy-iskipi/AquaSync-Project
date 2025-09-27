#!/usr/bin/env python3
"""
Simple script to populate compatibility data using the existing app structure.
Run this from the backend directory: python run_compatibility_population.py

Before running, set your Supabase credentials:
- Set environment variables SUPABASE_URL and SUPABASE_ANON_KEY, OR
- Replace the placeholder values in the get_supabase_client() function below
"""

import asyncio
import sys
import os
from typing import Dict, List, Any

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.conditional_compatibility import check_conditional_compatibility
from app.enhanced_compatibility_integration import check_enhanced_fish_compatibility
from supabase import create_client, Client

# Configuration - Update these with your actual Supabase credentials
SUPABASE_URL = "https://rdiwfttfxxpenrcxyfuv.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkaXdmdHRmeHhwZW5yY3h5ZnV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNDYzNTMsImV4cCI6MjA2NTcyMjM1M30.yYSE_9oREqsWhcL3O1isDmBLkszqrmzAOYHSGQHds8A"
# Use service role key for bulk operations (bypasses RLS policies)
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkaXdmdHRmeHhwZW5yY3h5ZnV2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDE0NjM1MywiZXhwIjoyMDY1NzIyMzUzfQ.s3bFGhsUl9YR5AEE355mCe_kFokgl0lQxM_vir9QIfU"  # Replace with your actual service role key

def get_supabase_client(use_service_key: bool = False) -> Client:
    """Get Supabase client with credentials from environment or config"""
    # Try environment variables first, then fall back to config
    supabase_url = os.getenv('SUPABASE_URL', SUPABASE_URL)
    
    if use_service_key:
        supabase_key = os.getenv('SUPABASE_SERVICE_KEY', SUPABASE_SERVICE_KEY)
        if supabase_key == "your-service-role-key":
            print("⚠️  Using anon key instead of service key (service key not configured)")
            supabase_key = os.getenv('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY)
    else:
        supabase_key = os.getenv('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY)
    
    return create_client(supabase_url, supabase_key)

async def get_fish_species_sample(limit: int = None) -> List[Dict[str, Any]]:
    """Get all fish species from database"""
    db = get_supabase_client()
    
    try:
        if limit:
            response = db.table('fish_species').select('*').limit(limit).execute()
        else:
            response = db.table('fish_species').select('*').execute()
        return response.data
    except Exception as e:
        print(f"Error fetching fish species: {e}")
        return []

def calculate_compatibility_for_pair(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate compatibility for a single fish pair using the enhanced compatibility system (same as real-time API)"""
    try:
        # Use the enhanced compatibility system (same as real-time API)
        compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
        
        # Calculate compatibility score based on level (scale to 0-9.99 range)
        if compatibility_level == "compatible":
            compatibility_score = round(8.5, 2)  # 85% scaled to 8.5
        elif compatibility_level == "conditional":
            compatibility_score = round(6.0, 2)  # 60% scaled to 6.0
        else:  # incompatible
            compatibility_score = round(2.0, 2)  # 20% scaled to 2.0
        
        # Calculate confidence score (scale to 0-9.99 range)
        raw_confidence = calculate_confidence_score(fish1, fish2)
        confidence_score = round(min(raw_confidence / 10.0, 9.99), 2)  # Scale from 0-100 to 0-10, cap at 9.99
        
        # Determine if compatible (includes conditional as compatible)
        is_compatible = compatibility_level in ["compatible", "conditional"]
        
        result = {
            "fish1_name": fish1['common_name'],
            "fish2_name": fish2['common_name'],
            "compatibility_level": compatibility_level,
            "is_compatible": is_compatible,
            "compatibility_reasons": reasons,
            "conditions": conditions,
            "compatibility_score": compatibility_score,
            "confidence_score": confidence_score,
            "generation_method": "enhanced_compatibility_system"
        }
        return validate_numeric_values(result, "compatibility")
        
    except Exception as e:
        print(f"Error calculating compatibility for {fish1['common_name']} + {fish2['common_name']}: {e}")
        result = {
            "fish1_name": fish1['common_name'],
            "fish2_name": fish2['common_name'],
            "compatibility_level": "unknown",
            "is_compatible": False,
            "compatibility_reasons": [f"Error: {str(e)}"],
            "conditions": [],
            "compatibility_score": round(0.0, 2),
            "confidence_score": round(0.0, 2),
            "generation_method": "error"
        }
        return validate_numeric_values(result, "compatibility_error")

def validate_numeric_values(data: Dict[str, Any], record_type: str = "unknown") -> Dict[str, Any]:
    """Validate and cap all numeric values to fit database constraints"""
    validated_data = data.copy()
    
    # Fields that should be capped at 9.99
    score_fields = ['compatibility_score', 'confidence_score']
    for field in score_fields:
        if field in validated_data:
            value = validated_data[field]
            if isinstance(value, (int, float)):
                validated_data[field] = round(min(max(value, 0.0), 9.99), 2)
    
    # Fields that should be capped at 99
    count_fields = ['total_fully_compatible', 'total_conditional', 'total_incompatible', 'total_recommended']
    for field in count_fields:
        if field in validated_data:
            value = validated_data[field]
            if isinstance(value, (int, float)):
                validated_data[field] = min(max(int(value), 0), 99)
    
    return validated_data

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

def generate_tankmate_recommendations_for_fish(fish: Dict[str, Any], compatibility_matrix: List[Dict[str, Any]]) -> Dict[str, Any]:
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
        else:  # incompatible
            incompatible.append(other_fish)
    
    # Sort lists
    fully_compatible.sort()
    conditional.sort(key=lambda x: x['name'])
    incompatible.sort()
    
    # Generate special requirements
    special_requirements = generate_special_requirements(fish)
    
    result = {
        "fish_name": fish_name,
        "fully_compatible_tankmates": fully_compatible[:20],  # Top 20
        "conditional_tankmates": conditional[:15],  # Top 15
        "incompatible_tankmates": incompatible[:10],  # Top 10
        "special_requirements": special_requirements,
        "care_level": fish.get('care_level', 'Intermediate'),
        "confidence_score": calculate_fish_confidence_score(fish),
        "total_fully_compatible": min(len(fully_compatible), 99),  # Cap at 99
        "total_conditional": min(len(conditional), 99),  # Cap at 99
        "total_incompatible": min(len(incompatible), 99),  # Cap at 99
        "total_recommended": min(len(fully_compatible) + len(conditional), 99)  # Cap at 99
    }
    return validate_numeric_values(result, "tankmate_recommendation")

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
    
    result = round((score / total_fields) * 10.0, 2)  # Scale to 0-10 range, rounded to 2 decimal places
    return min(result, 9.99)  # Cap at 9.99

async def populate_sample_data():
    """Populate database with sample data for testing"""
    print("🚀 Starting compatibility data population...")
    
    # Check if credentials are configured
    if SUPABASE_URL == "https://your-project.supabase.co" or SUPABASE_ANON_KEY == "your-anon-key":
        print("❌ Please configure your Supabase credentials first!")
        print("   Update SUPABASE_URL and SUPABASE_ANON_KEY in this script")
        print("   Or set environment variables SUPABASE_URL and SUPABASE_ANON_KEY")
        return
    
    # Get all fish species from database
    fish_species = await get_fish_species_sample()
    if not fish_species:
        print("❌ No fish species found in database!")
        return
    
    print(f"📊 Found {len(fish_species)} fish species")
    
    # Calculate compatibility matrix
    print("🔄 Calculating compatibility matrix...")
    compatibility_matrix = []
    total_pairs = len(fish_species) * (len(fish_species) - 1) // 2
    processed = 0
    
    for i, fish1 in enumerate(fish_species):
        for j, fish2 in enumerate(fish_species):
            if i < j:  # Avoid duplicate pairs
                processed += 1
                print(f"   Processing pair {processed}/{total_pairs}: {fish1['common_name']} + {fish2['common_name']}")
                
                compatibility_entry = calculate_compatibility_for_pair(fish1, fish2)
                compatibility_matrix.append(compatibility_entry)
    
    print(f"✅ Generated {len(compatibility_matrix)} compatibility entries")
    
    # Generate tankmate recommendations
    print("🔄 Generating tankmate recommendations...")
    tankmate_recommendations = []
    
    for fish in fish_species:
        print(f"   Processing tankmates for: {fish['common_name']}")
        recommendation = generate_tankmate_recommendations_for_fish(fish, compatibility_matrix)
        tankmate_recommendations.append(recommendation)
    
    print(f"✅ Generated {len(tankmate_recommendations)} tankmate recommendation entries")
    
    # Upload to database
    print("🔄 Uploading to database...")
    db = get_supabase_client(use_service_key=True)  # Use service key to bypass RLS
    
    try:
        # Clear existing data
        print("   Clearing existing data...")
        db.table('fish_compatibility_matrix').delete().neq('fish1_name', '').execute()
        db.table('fish_tankmate_recommendations').delete().neq('fish_name', '').execute()
        
        # Debug: Check first few records for numeric values
        print("   🔍 Debugging first few records...")
        for i, record in enumerate(compatibility_matrix[:3]):
            print(f"     Record {i+1}: {record['fish1_name']} + {record['fish2_name']}")
            print(f"       compatibility_score: {record.get('compatibility_score')} (type: {type(record.get('compatibility_score'))})")
            print(f"       confidence_score: {record.get('confidence_score')} (type: {type(record.get('confidence_score'))})")
        
        # Insert compatibility matrix in batches
        print("   Uploading compatibility matrix in batches...")
        batch_size = 100  # Upload 100 records at a time
        total_batches = (len(compatibility_matrix) + batch_size - 1) // batch_size
        for i in range(0, len(compatibility_matrix), batch_size):
            batch = compatibility_matrix[i:i + batch_size]
            batch_num = i//batch_size + 1
            print(f"     Uploading batch {batch_num}/{total_batches} ({len(batch)} records)")
            try:
                db.table('fish_compatibility_matrix').insert(batch).execute()
                print(f"     ✅ Batch {batch_num} uploaded successfully")
            except Exception as e:
                print(f"     ❌ Error uploading batch {batch_num}: {e}")
                # Debug the problematic batch
                print(f"     🔍 Debugging problematic batch {batch_num}:")
                for j, record in enumerate(batch[:3]):
                    print(f"       Record {j+1}: {record['fish1_name']} + {record['fish2_name']}")
                    print(f"         compatibility_score: {record.get('compatibility_score')}")
                    print(f"         confidence_score: {record.get('confidence_score')}")
                raise
        
        # Insert tankmate recommendations in batches
        print("   Uploading tankmate recommendations in batches...")
        batch_size = 50  # Upload 50 records at a time
        total_batches = (len(tankmate_recommendations) + batch_size - 1) // batch_size
        for i in range(0, len(tankmate_recommendations), batch_size):
            batch = tankmate_recommendations[i:i + batch_size]
            batch_num = i//batch_size + 1
            print(f"     Uploading batch {batch_num}/{total_batches} ({len(batch)} records)")
            try:
                db.table('fish_tankmate_recommendations').insert(batch).execute()
                print(f"     ✅ Batch {batch_num} uploaded successfully")
            except Exception as e:
                print(f"     ❌ Error uploading batch {batch_num}: {e}")
                raise
        
        print("🎉 Database population completed successfully!")
        print(f"📈 Final Statistics:")
        print(f"   - Fish species processed: {len(fish_species)}")
        print(f"   - Compatibility pairs: {len(compatibility_matrix)}")
        print(f"   - Tankmate recommendations: {len(tankmate_recommendations)}")
        
        # Show some examples
        print("\n📋 Sample Results:")
        if compatibility_matrix:
            sample = compatibility_matrix[0]
            print(f"   Example compatibility: {sample['fish1_name']} + {sample['fish2_name']} = {sample['compatibility_level']}")
        
        if tankmate_recommendations:
            sample = tankmate_recommendations[0]
            print(f"   Example tankmates for {sample['fish_name']}: {len(sample['fully_compatible_tankmates'])} fully compatible, {len(sample['conditional_tankmates'])} conditional")
        
    except Exception as e:
        print(f"❌ Error uploading to database: {e}")

if __name__ == "__main__":
    print("🔧 Compatibility Data Population Script")
    print("=" * 50)
    asyncio.run(populate_sample_data())
