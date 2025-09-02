#!/usr/bin/env python3
"""
Test Enhanced Tankmate Endpoints

This script tests the new enhanced tankmate recommendation endpoints
to ensure they're working correctly with the updated database structure.
"""

import requests
import json
import sys

# Configuration
BASE_URL = "http://localhost:8000"  # Update this to your backend URL

def test_tankmate_details(fish_name):
    """Test the /tankmate-details/{fish_name} endpoint"""
    print(f"\n🧪 Testing tankmate details for: {fish_name}")
    
    try:
        response = requests.get(f"{BASE_URL}/tankmate-details/{fish_name}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success! Found data for {fish_name}")
            print(f"   Fully compatible: {len(data.get('fully_compatible_tankmates', []))}")
            print(f"   Conditional: {len(data.get('conditional_tankmates', []))}")
            print(f"   Incompatible: {len(data.get('incompatible_tankmates', []))}")
            print(f"   Confidence: {data.get('confidence_score', 0):.2f}")
            return True
        else:
            print(f"❌ Failed with status {response.status_code}: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def test_compatibility_matrix(fish1, fish2):
    """Test the /compatibility-matrix/{fish1}/{fish2} endpoint"""
    print(f"\n🧪 Testing compatibility matrix: {fish1} + {fish2}")
    
    try:
        response = requests.get(f"{BASE_URL}/compatibility-matrix/{fish1}/{fish2}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success! Compatibility data found")
            print(f"   Level: {data.get('compatibility_level', 'unknown')}")
            print(f"   Compatible: {data.get('is_compatible', False)}")
            print(f"   Score: {data.get('compatibility_score', 0):.2f}")
            print(f"   Confidence: {data.get('confidence_score', 0):.2f}")
            return True
        else:
            print(f"❌ Failed with status {response.status_code}: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def test_enhanced_recommendations(fish_names):
    """Test the enhanced /tankmate-recommendations endpoint"""
    print(f"\n🧪 Testing enhanced tankmate recommendations for: {fish_names}")
    
    try:
        payload = {"fish_names": fish_names}
        response = requests.post(
            f"{BASE_URL}/tankmate-recommendations",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success! Enhanced recommendations found")
            print(f"   Total recommendations: {data.get('total_found', 0)}")
            print(f"   Detailed data for {len(data.get('detailed_recommendations', {}))} fish")
            
            # Show detailed info for each fish
            for fish_name, details in data.get('detailed_recommendations', {}).items():
                print(f"   {fish_name}:")
                print(f"     - Fully compatible: {len(details.get('fully_compatible', []))}")
                print(f"     - Conditional: {len(details.get('conditional', []))}")
                print(f"     - Incompatible: {len(details.get('incompatible', []))}")
            
            return True
        else:
            print(f"❌ Failed with status {response.status_code}: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def main():
    """Run all tests"""
    print("🚀 Testing Enhanced Tankmate Endpoints")
    print("=" * 50)
    
    # Test fish names (update these based on your database)
    test_fish = [
        "betta",
        "goldfish", 
        "neon tetra",
        "angelfish",
        "oscar"
    ]
    
    success_count = 0
    total_tests = 0
    
    # Test 1: Tankmate details for individual fish
    for fish in test_fish[:3]:  # Test first 3
        total_tests += 1
        if test_tankmate_details(fish):
            success_count += 1
    
    # Test 2: Compatibility matrix between fish pairs
    test_pairs = [
        ("betta", "neon tetra"),
        ("goldfish", "angelfish"),
        ("oscar", "angelfish")
    ]
    
    for fish1, fish2 in test_pairs:
        total_tests += 1
        if test_compatibility_matrix(fish1, fish2):
            success_count += 1
    
    # Test 3: Enhanced recommendations for multiple fish
    total_tests += 1
    if test_enhanced_recommendations(["betta", "goldfish"]):
        success_count += 1
    
    # Summary
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {success_count}/{total_tests} passed")
    
    if success_count == total_tests:
        print("🎉 All tests passed! Enhanced endpoints are working correctly.")
    else:
        print("⚠️  Some tests failed. Check the backend logs for details.")
    
    return success_count == total_tests

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
