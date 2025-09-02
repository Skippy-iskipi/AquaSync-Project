#!/usr/bin/env python3
"""
Enhanced Fish Data Scraper for Comprehensive Compatibility Analysis

This scraper collects all the comprehensive attributes needed for accurate
fish compatibility checking, including water parameters, behavioral traits,
and special requirements.
"""

import asyncio
import aiohttp
import json
import logging
import re
from typing import Dict, List, Optional, Any
import sys
import os
from dataclasses import asdict

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.models.enhanced_fish_model import EnhancedFishData, WaterType, Temperament, SocialBehavior, ActivityLevel, TankZone, Diet, FinVulnerability, BreedingBehavior
from app.supabase_config import get_supabase_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EnhancedFishScraper:
    """Comprehensive fish data scraper for all compatibility attributes"""
    
    def __init__(self):
        self.api_url = "https://en.wikipedia.org/w/api.php"
        self.supabase = get_supabase_client()
        
        # Known fish data for manual fixes
        self.manual_fish_data = self._load_manual_fish_data()
    
    def _load_manual_fish_data(self) -> Dict[str, Dict]:
        """Load manually curated fish data for accurate compatibility"""
        return {
            "blue_tang": {
                "common_name": "Blue Tang",
                "scientific_name": "Paracanthurus hepatus",
                "water_type": WaterType.SALTWATER,
                "temperature_min": 24.0,
                "temperature_max": 28.0,
                "ph_min": 8.0,
                "ph_max": 8.4,
                "temperament": Temperament.PEACEFUL,
                "social_behavior": SocialBehavior.COMMUNITY,  # NOT solitary!
                "activity_level": ActivityLevel.MODERATE,
                "max_size_cm": 30.0,
                "min_tank_size_l": 300.0,
                "tank_zone": TankZone.ALL,
                "diet": Diet.OMNIVORE,
                "fin_vulnerability": FinVulnerability.HARDY,
                "fin_nipper": False,
                "reef_safe": True,
                "care_level": "Intermediate"
            },
            "clownfish": {
                "common_name": "Clownfish",
                "scientific_name": "Amphiprion ocellatus",
                "water_type": WaterType.SALTWATER,
                "temperature_min": 24.0,
                "temperature_max": 27.0,
                "ph_min": 8.0,
                "ph_max": 8.4,
                "temperament": Temperament.PEACEFUL,
                "social_behavior": SocialBehavior.PAIRS,
                "activity_level": ActivityLevel.MODERATE,
                "max_size_cm": 10.0,
                "min_tank_size_l": 75.0,
                "tank_zone": TankZone.MID,
                "diet": Diet.OMNIVORE,
                "fin_vulnerability": FinVulnerability.HARDY,
                "fin_nipper": False,
                "reef_safe": True,
                "care_level": "Beginner"
            },
            "yellow_tang": {
                "common_name": "Yellow Tang",
                "scientific_name": "Zebrasoma flavescens",
                "water_type": WaterType.SALTWATER,
                "temperature_min": 24.0,
                "temperature_max": 28.0,
                "ph_min": 8.0,
                "ph_max": 8.4,
                "temperament": Temperament.SEMI_AGGRESSIVE,
                "social_behavior": SocialBehavior.TERRITORIAL,
                "activity_level": ActivityLevel.HIGH,
                "max_size_cm": 20.0,
                "min_tank_size_l": 250.0,
                "tank_zone": TankZone.ALL,
                "diet": Diet.HERBIVORE,
                "fin_vulnerability": FinVulnerability.HARDY,
                "fin_nipper": False,
                "territorial_space_cm": 50.0,
                "reef_safe": True,
                "care_level": "Intermediate"
            },
            "betta": {
                "common_name": "Betta",
                "scientific_name": "Betta splendens",
                "water_type": WaterType.FRESHWATER,
                "temperature_min": 24.0,
                "temperature_max": 28.0,
                "ph_min": 6.0,
                "ph_max": 7.5,
                "hardness_min": 5.0,
                "hardness_max": 20.0,
                "temperament": Temperament.AGGRESSIVE,
                "social_behavior": SocialBehavior.SOLITARY,
                "activity_level": ActivityLevel.MODERATE,
                "max_size_cm": 6.0,
                "min_tank_size_l": 20.0,
                "tank_zone": TankZone.ALL,
                "diet": Diet.CARNIVORE,
                "fin_vulnerability": FinVulnerability.VULNERABLE,
                "fin_nipper": True,
                "breeding_behavior": BreedingBehavior.BUBBLE_NESTER,
                "territorial_space_cm": 30.0,
                "care_level": "Beginner"
            },
            "neon_tetra": {
                "common_name": "Neon Tetra",
                "scientific_name": "Paracheirodon innesi",
                "water_type": WaterType.FRESHWATER,
                "temperature_min": 20.0,
                "temperature_max": 26.0,
                "ph_min": 6.0,
                "ph_max": 7.0,
                "hardness_min": 1.0,
                "hardness_max": 10.0,
                "temperament": Temperament.PEACEFUL,
                "social_behavior": SocialBehavior.SCHOOLING,
                "activity_level": ActivityLevel.MODERATE,
                "max_size_cm": 4.0,
                "min_tank_size_l": 40.0,
                "tank_zone": TankZone.MID,
                "diet": Diet.OMNIVORE,
                "fin_vulnerability": FinVulnerability.MODERATE,
                "fin_nipper": False,
                "schooling_min_number": 6,
                "care_level": "Beginner"
            },
            "angelfish": {
                "common_name": "Angelfish",
                "scientific_name": "Pterophyllum scalare",
                "water_type": WaterType.FRESHWATER,
                "temperature_min": 24.0,
                "temperature_max": 28.0,
                "ph_min": 6.0,
                "ph_max": 7.5,
                "hardness_min": 3.0,
                "hardness_max": 15.0,
                "temperament": Temperament.SEMI_AGGRESSIVE,
                "social_behavior": SocialBehavior.PAIRS,
                "activity_level": ActivityLevel.MODERATE,
                "max_size_cm": 15.0,
                "min_tank_size_l": 150.0,
                "tank_zone": TankZone.MID,
                "diet": Diet.OMNIVORE,
                "fin_vulnerability": FinVulnerability.VULNERABLE,
                "fin_nipper": False,
                "breeding_behavior": BreedingBehavior.EGG_LAYER,
                "care_level": "Intermediate"
            },
            "tiger_barb": {
                "common_name": "Tiger Barb",
                "scientific_name": "Puntigrus tetrazona",
                "water_type": WaterType.FRESHWATER,
                "temperature_min": 20.0,
                "temperature_max": 26.0,
                "ph_min": 6.0,
                "ph_max": 8.0,
                "hardness_min": 5.0,
                "hardness_max": 20.0,
                "temperament": Temperament.SEMI_AGGRESSIVE,
                "social_behavior": SocialBehavior.SCHOOLING,
                "activity_level": ActivityLevel.HIGH,
                "max_size_cm": 7.0,
                "min_tank_size_l": 80.0,
                "tank_zone": TankZone.MID,
                "diet": Diet.OMNIVORE,
                "fin_vulnerability": FinVulnerability.HARDY,
                "fin_nipper": True,  # Known fin nippers!
                "schooling_min_number": 6,
                "care_level": "Beginner"
            }
        }
    
    async def scrape_enhanced_fish_data(self, fish_names: List[str]) -> Dict[str, EnhancedFishData]:
        """Scrape comprehensive fish data for compatibility analysis"""
        
        results = {}
        
        for fish_name in fish_names:
            logger.info(f"Processing enhanced data for: {fish_name}")
            
            # Check if we have manual data
            fish_key = fish_name.lower().replace(' ', '_').replace('-', '_')
            if fish_key in self.manual_fish_data:
                logger.info(f"  Using manual data for {fish_name}")
                manual_data = self.manual_fish_data[fish_key].copy()
                fish_data = EnhancedFishData(**manual_data)
                fish_data.sources = ["manual_curation"]
                fish_data.confidence_score = 1.0
            else:
                # Scrape from web sources
                fish_data = await self._scrape_fish_data(fish_name)
            
            if fish_data:
                results[fish_name] = fish_data
                # Save to database
                await self._save_enhanced_data(fish_data)
        
        return results
    
    async def _scrape_fish_data(self, fish_name: str) -> Optional[EnhancedFishData]:
        """Scrape fish data from web sources"""
        # This would be implemented to scrape from multiple sources
        # For now, return basic data structure
        return EnhancedFishData(common_name=fish_name)
    
    async def _save_enhanced_data(self, fish_data: EnhancedFishData):
        """Save enhanced fish data to database"""
        try:
            # Convert enhanced data to database format
            db_data = {
                'common_name': fish_data.common_name,
                'scientific_name': fish_data.scientific_name,
                'water_type': fish_data.water_type.value if fish_data.water_type else None,
                'temperature_min': fish_data.temperature_min,
                'temperature_max': fish_data.temperature_max,
                'ph_min': fish_data.ph_min,
                'ph_max': fish_data.ph_max,
                'hardness_min': fish_data.hardness_min,
                'hardness_max': fish_data.hardness_max,
                'temperament': fish_data.temperament.value if fish_data.temperament else None,
                'social_behavior': fish_data.social_behavior.value if fish_data.social_behavior else None,
                'activity_level': fish_data.activity_level.value if fish_data.activity_level else None,
                'max_size_(cm)': fish_data.max_size_cm,
                'minimum_tank_size_(l)': fish_data.min_tank_size_l,
                'tank_zone': fish_data.tank_zone.value if fish_data.tank_zone else None,
                'diet': fish_data.diet.value if fish_data.diet else None,
                'fin_vulnerability': fish_data.fin_vulnerability.value if fish_data.fin_vulnerability else None,
                'fin_nipper': fish_data.fin_nipper,
                'breeding_behavior': fish_data.breeding_behavior.value if fish_data.breeding_behavior else None,
                'reef_safe': fish_data.reef_safe,
                'schooling_min_number': fish_data.schooling_min_number,
                'territorial_space_cm': fish_data.territorial_space_cm,
                'care_level': fish_data.care_level,
                'confidence_score': fish_data.confidence_score,
                'data_sources': fish_data.sources
            }
            
            # Remove None values
            db_data = {k: v for k, v in db_data.items() if v is not None}
            
            # Update database
            response = self.supabase.table('fish_species').upsert(db_data).execute()
            logger.info(f"  ✅ Saved enhanced data for {fish_data.common_name}")
            
        except Exception as e:
            logger.error(f"  ❌ Failed to save {fish_data.common_name}: {str(e)}")

async def test_enhanced_compatibility():
    """Test the enhanced compatibility system"""
    
    # Test fish with known compatibility issues
    test_fish = [
        "Blue Tang", "Clownfish", "Yellow Tang", 
        "Betta", "Neon Tetra", "Angelfish", "Tiger Barb"
    ]
    
    scraper = EnhancedFishScraper()
    fish_data = await scraper.scrape_enhanced_fish_data(test_fish)
    
    # Test some compatibility combinations
    from app.models.enhanced_fish_model import check_enhanced_compatibility
    
    test_pairs = [
        ("Blue Tang", "Clownfish"),
        ("Betta", "Neon Tetra"),
        ("Angelfish", "Tiger Barb"),
        ("Yellow Tang", "Blue Tang")
    ]
    
    print("=== Enhanced Compatibility Test Results ===\n")
    
    for fish1_name, fish2_name in test_pairs:
        if fish1_name in fish_data and fish2_name in fish_data:
            fish1 = fish_data[fish1_name]
            fish2 = fish_data[fish2_name]
            
            compatibility, reasons, conditions = check_enhanced_compatibility(fish1, fish2)
            
            print(f"🐟 {fish1_name} + {fish2_name}")
            print(f"   Compatibility: {compatibility.upper()}")
            if reasons:
                print(f"   Reasons: {reasons[:2]}")  # Show first 2 reasons
            if conditions:
                print(f"   Conditions: {conditions[:2]}")  # Show first 2 conditions
            print()
    
    # Save results to file
    results_dict = {}
    for name, data in fish_data.items():
        results_dict[name] = asdict(data)
    
    with open('enhanced_fish_data.json', 'w') as f:
        json.dump(results_dict, f, indent=2, default=str)
    
    print(f"Enhanced data saved for {len(fish_data)} fish")

if __name__ == "__main__":
    asyncio.run(test_enhanced_compatibility())
