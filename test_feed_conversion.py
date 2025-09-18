#!/usr/bin/env python3
"""
Test script for the updated feed inventory recommendations endpoint
Tests both piece-based and gram-based inputs
"""

import requests
import json

# Test data
BASE_URL = "http://localhost:8000"

def test_piece_based_input():
    """Test with piece-based feed input (new format)"""
    print("=== Testing Piece-Based Input ===")
    
    test_data = {
        "fish_selections": {
            "Guppy": 6,
            "Molly": 4
        },
        "available_feeds": {
            "Tropical Flakes": {
                "amount": 100,  # 100 flakes
                "unit": "pieces"
            },
            "Community Pellets": {
                "amount": 50,   # 50 pellets
                "unit": "pieces"
            }
        },
        "feeding_frequency": 2,
        "user_preferences": {}
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/calculate-feed-inventory-recommendations/",
            json=test_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Success!")
            print(f"Response: {json.dumps(result, indent=2)}")
            
            # Check if conversion worked
            if 'inventory_analysis' in result:
                for feed_name, analysis in result['inventory_analysis'].items():
                    print(f"\n{feed_name}:")
                    print(f"  Available: {analysis.get('available_grams', 'N/A')}g")
                    print(f"  Daily consumption: {analysis.get('daily_consumption_grams', 'N/A')}g/day")
                    print(f"  Days until empty: {analysis.get('days_until_empty', 'N/A')}")
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - make sure the server is running on localhost:8000")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_legacy_gram_input():
    """Test with legacy gram-based input"""
    print("\n=== Testing Legacy Gram-Based Input ===")
    
    test_data = {
        "fish_selections": {
            "Guppy": 6,
            "Molly": 4
        },
        "available_feeds": {
            "Tropical Flakes": 0.3,  # 0.3 grams (legacy format)
            "Community Pellets": 0.75  # 0.75 grams (legacy format)
        },
        "feeding_frequency": 2,
        "user_preferences": {}
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/calculate-feed-inventory-recommendations/",
            json=test_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Success!")
            print(f"Response: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - make sure the server is running on localhost:8000")
    except Exception as e:
        print(f"❌ Error: {e}")

def test_mixed_input():
    """Test with mixed piece and gram inputs"""
    print("\n=== Testing Mixed Input Format ===")
    
    test_data = {
        "fish_selections": {
            "Guppy": 6
        },
        "available_feeds": {
            "Tropical Flakes": {
                "amount": 200,  # 200 flakes
                "unit": "pieces"
            },
            "Bloodworms": {
                "amount": 5.0,  # 5 grams
                "unit": "grams"
            }
        },
        "feeding_frequency": 2,
        "user_preferences": {}
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/calculate-feed-inventory-recommendations/",
            json=test_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Success!")
            print(f"Response: {json.dumps(result, indent=2)}")
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - make sure the server is running on localhost:8000")
    except Exception as e:
        print(f"❌ Error: {e}")

def show_conversion_examples():
    """Show expected conversion examples"""
    print("\n=== Expected Conversion Examples ===")
    
    conversions = [
        ("Tropical Flakes", 100, "pieces", 100 * 0.003),
        ("Community Pellets", 50, "pieces", 50 * 0.015),
        ("Bloodworms", 100, "pieces", 100 * 0.002),
        ("Algae Wafers", 10, "pieces", 10 * 0.500),
    ]
    
    for feed_name, amount, unit, expected_grams in conversions:
        print(f"{feed_name}: {amount} {unit} → {expected_grams}g")

if __name__ == "__main__":
    print("Feed Inventory Conversion Test")
    print("=" * 40)
    
    show_conversion_examples()
    test_piece_based_input()
    test_legacy_gram_input()
    test_mixed_input()
    
    print("\n" + "=" * 40)
    print("Test completed!")
