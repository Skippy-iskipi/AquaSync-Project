#!/usr/bin/env python3
"""
Fish Data Migration Script

Migrates existing fish_species data to include enhanced compatibility attributes.
Uses a combination of known fish data, intelligent defaults, and data inference.
"""

import asyncio
import logging
import sys
import os
from typing import Dict, List, Optional, Any

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.supabase_config import get_supabase_client

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FishDataMigrator:
    """Migrates existing fish data to enhanced attribute system"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
        
        # Comprehensive fish attribute mappings
        self.known_fish_data = {
            # Saltwater fish
            "blue_tang": {
                "temperature_min": 24.0, "temperature_max": 28.0,
                "ph_min": 8.0, "ph_max": 8.4,
                "hardness_min": 8.0, "hardness_max": 12.0,
                "activity_level": "Moderate", "tank_zone": "All",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "reef_safe": True, "territorial_space_cm": 30.0,
                "care_level": "Intermediate", "confidence_score": 0.95
            },
            "clownfish": {
                "temperature_min": 24.0, "temperature_max": 27.0,
                "ph_min": 8.0, "ph_max": 8.4,
                "hardness_min": 8.0, "hardness_max": 12.0,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "reef_safe": True, "schooling_min_number": 2,
                "care_level": "Beginner", "confidence_score": 0.95
            },
            "yellow_tang": {
                "temperature_min": 24.0, "temperature_max": 28.0,
                "ph_min": 8.0, "ph_max": 8.4,
                "hardness_min": 8.0, "hardness_max": 12.0,
                "activity_level": "High", "tank_zone": "All",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "reef_safe": True, "territorial_space_cm": 50.0,
                "care_level": "Intermediate", "confidence_score": 0.95
            },
            "coral_beauty": {
                "temperature_min": 24.0, "temperature_max": 27.0,
                "ph_min": 8.0, "ph_max": 8.4,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Hardy", "fin_nipper": True,  # Can nip soft corals
                "reef_safe": False, "care_level": "Intermediate"
            },
            
            # Aggressive/Territorial freshwater
            "betta": {
                "temperature_min": 24.0, "temperature_max": 28.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "hardness_min": 5.0, "hardness_max": 20.0,
                "activity_level": "Moderate", "tank_zone": "All",
                "fin_vulnerability": "Vulnerable", "fin_nipper": True,
                "breeding_behavior": "Bubble nester", "territorial_space_cm": 30.0,
                "care_level": "Beginner", "confidence_score": 0.95
            },
            "paradise_fish": {
                "temperature_min": 16.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 8.0,
                "activity_level": "Moderate", "tank_zone": "All",
                "fin_vulnerability": "Moderate", "fin_nipper": True,
                "territorial_space_cm": 40.0, "care_level": "Intermediate"
            },
            "red_jewel": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 6.5, "ph_max": 7.5,
                "activity_level": "High", "tank_zone": "Bottom",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "breeding_behavior": "Egg layer", "territorial_space_cm": 50.0,
                "care_level": "Intermediate"
            },
            
            # Peaceful schooling fish
            "neon_tetra": {
                "temperature_min": 20.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 7.0,
                "hardness_min": 1.0, "hardness_max": 10.0,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Moderate", "fin_nipper": False,
                "schooling_min_number": 6, "care_level": "Beginner",
                "confidence_score": 0.95
            },
            "cardinal_tetra": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 5.0, "ph_max": 6.5,
                "hardness_min": 1.0, "hardness_max": 8.0,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Moderate", "fin_nipper": False,
                "schooling_min_number": 6, "care_level": "Beginner"
            },
            "black_skirt_tetra": {
                "temperature_min": 20.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Hardy", "fin_nipper": True,  # Known fin nipper
                "schooling_min_number": 6, "care_level": "Beginner"
            },
            
            # Semi-aggressive schooling fish
            "tiger_barb": {
                "temperature_min": 20.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 8.0,
                "hardness_min": 5.0, "hardness_max": 20.0,
                "activity_level": "High", "tank_zone": "Mid",
                "fin_vulnerability": "Hardy", "fin_nipper": True,  # Major fin nipper
                "schooling_min_number": 6, "care_level": "Beginner",
                "confidence_score": 0.95
            },
            "tinfoil_barb": {
                "temperature_min": 22.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "activity_level": "High", "tank_zone": "All",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "schooling_min_number": 4, "care_level": "Intermediate"
            },
            
            # Angelfish and similar
            "angelfish": {
                "temperature_min": 24.0, "temperature_max": 28.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "hardness_min": 3.0, "hardness_max": 15.0,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Vulnerable", "fin_nipper": False,
                "breeding_behavior": "Egg layer", "care_level": "Intermediate",
                "confidence_score": 0.95
            },
            "discus": {
                "temperature_min": 28.0, "temperature_max": 32.0,
                "ph_min": 6.0, "ph_max": 7.0,
                "hardness_min": 1.0, "hardness_max": 8.0,
                "activity_level": "Low", "tank_zone": "Mid",
                "fin_vulnerability": "Vulnerable", "fin_nipper": False,
                "care_level": "Expert", "special_diet_requirements": "High protein, frequent feeding"
            },
            
            # Bottom dwellers
            "corydoras_catfish": {
                "temperature_min": 22.0, "temperature_max": 26.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "activity_level": "Low", "tank_zone": "Bottom",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "schooling_min_number": 3, "hiding_spots_required": True,
                "care_level": "Beginner"
            },
            "bristlenose_pleco": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 6.5, "ph_max": 7.5,
                "activity_level": "Nocturnal", "tank_zone": "Bottom",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "hiding_spots_required": True, "care_level": "Beginner"
            },
            "common_pleco": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 6.5, "ph_max": 7.5,
                "activity_level": "Nocturnal", "tank_zone": "Bottom",
                "fin_vulnerability": "Hardy", "fin_nipper": False,
                "care_level": "Intermediate", "special_diet_requirements": "Vegetable matter, driftwood"
            },
            
            # Gouramis
            "dwarf_gourami": {
                "temperature_min": 24.0, "temperature_max": 28.0,
                "ph_min": 6.0, "ph_max": 7.5,
                "activity_level": "Moderate", "tank_zone": "Top",
                "fin_vulnerability": "Vulnerable", "fin_nipper": False,
                "breeding_behavior": "Bubble nester", "care_level": "Beginner"
            },
            
            # Livebearers
            "guppy": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 7.0, "ph_max": 8.5,
                "hardness_min": 10.0, "hardness_max": 25.0,
                "activity_level": "Moderate", "tank_zone": "Top",
                "fin_vulnerability": "Vulnerable", "fin_nipper": False,
                "breeding_behavior": "Live bearer", "care_level": "Beginner"
            },
            "swordtail": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 7.0, "ph_max": 8.5,
                "activity_level": "Moderate", "tank_zone": "Mid",
                "fin_vulnerability": "Moderate", "fin_nipper": False,
                "breeding_behavior": "Live bearer", "care_level": "Beginner"
            }
        }
        
        # Default values based on existing attributes
        self.temperament_defaults = {
            "Peaceful": {
                "activity_level": "Moderate",
                "fin_vulnerability": "Moderate",
                "fin_nipper": False,
                "care_level": "Beginner"
            },
            "Semi-aggressive": {
                "activity_level": "Moderate",
                "fin_vulnerability": "Hardy",
                "fin_nipper": False,
                "care_level": "Intermediate",
                "territorial_space_cm": 25.0
            },
            "Aggressive": {
                "activity_level": "High",
                "fin_vulnerability": "Hardy",
                "fin_nipper": True,
                "care_level": "Intermediate",
                "territorial_space_cm": 40.0
            }
        }
        
        self.water_type_defaults = {
            "Freshwater": {
                "temperature_min": 22.0, "temperature_max": 26.0,
                "ph_min": 6.5, "ph_max": 7.5,
                "hardness_min": 5.0, "hardness_max": 15.0,
                "reef_safe": None
            },
            "Saltwater": {
                "temperature_min": 24.0, "temperature_max": 27.0,
                "ph_min": 8.0, "ph_max": 8.4,
                "hardness_min": 8.0, "hardness_max": 12.0,
                "reef_safe": True
            },
            "Brackish": {
                "temperature_min": 22.0, "temperature_max": 28.0,
                "ph_min": 7.5, "ph_max": 8.5,
                "hardness_min": 10.0, "hardness_max": 20.0,
                "reef_safe": None
            }
        }
        
        self.social_behavior_defaults = {
            "Schooling": {
                "schooling_min_number": 6,
                "tank_zone": "Mid",
                "activity_level": "Moderate"
            },
            "Pairs": {
                "schooling_min_number": 2,
                "tank_zone": "Mid"
            },
            "Community": {
                "schooling_min_number": 1,
                "tank_zone": "Mid"
            },
            "Solitary": {
                "schooling_min_number": 1,
                "territorial_space_cm": 30.0
            }
        }
    
    async def get_existing_fish(self) -> List[Dict]:
        """Get all existing fish from database"""
        try:
            response = self.supabase.table('fish_species').select('*').execute()
            logger.info(f"Retrieved {len(response.data)} existing fish records")
            return response.data
        except Exception as e:
            logger.error(f"Failed to retrieve fish data: {str(e)}")
            return []
    
    def get_fish_key(self, common_name: str) -> str:
        """Convert fish name to lookup key"""
        return common_name.lower().replace(' ', '_').replace('-', '_')
    
    def generate_enhanced_attributes(self, fish: Dict) -> Dict:
        """Generate enhanced attributes for a fish based on existing data"""
        fish_key = self.get_fish_key(fish['common_name'])
        enhanced = {}
        
        # Start with known data if available
        if fish_key in self.known_fish_data:
            logger.info(f"  Using known data for {fish['common_name']}")
            enhanced.update(self.known_fish_data[fish_key])
            enhanced['confidence_score'] = enhanced.get('confidence_score', 0.9)
            enhanced['data_sources'] = ['manual_curation']
        else:
            # Generate from existing attributes
            logger.info(f"  Generating attributes for {fish['common_name']}")
            enhanced['confidence_score'] = 0.6  # Lower confidence for generated data
            enhanced['data_sources'] = ['attribute_inference']
            
            # Water type defaults
            water_type = fish.get('water_type', 'Freshwater')
            if water_type in self.water_type_defaults:
                enhanced.update(self.water_type_defaults[water_type])
            
            # Temperament defaults
            temperament = fish.get('temperament', 'Peaceful')
            if temperament in self.temperament_defaults:
                enhanced.update(self.temperament_defaults[temperament])
            
            # Social behavior defaults
            social_behavior = fish.get('social_behavior', 'Community')
            if social_behavior in self.social_behavior_defaults:
                enhanced.update(self.social_behavior_defaults[social_behavior])
            
            # Size-based adjustments
            max_size = fish.get('max_size_(cm)', 10.0)
            if max_size > 30:
                enhanced['activity_level'] = 'High'
                enhanced['care_level'] = 'Intermediate'
                enhanced['territorial_space_cm'] = max_size * 2
            elif max_size < 5:
                enhanced['fin_vulnerability'] = 'Vulnerable'
                enhanced['schooling_min_number'] = 6
            
            # Tank zone inference
            if 'catfish' in fish['common_name'].lower() or 'pleco' in fish['common_name'].lower():
                enhanced['tank_zone'] = 'Bottom'
                enhanced['activity_level'] = 'Nocturnal'
                enhanced['hiding_spots_required'] = True
            elif 'guppy' in fish['common_name'].lower() or 'gourami' in fish['common_name'].lower():
                enhanced['tank_zone'] = 'Top'
            else:
                enhanced['tank_zone'] = 'Mid'
            
            # Breeding behavior inference
            if 'tetra' in fish['common_name'].lower():
                enhanced['breeding_behavior'] = 'Egg scatterer'
            elif 'cichlid' in fish['common_name'].lower():
                enhanced['breeding_behavior'] = 'Egg layer'
            elif 'guppy' in fish['common_name'].lower() or 'molly' in fish['common_name'].lower():
                enhanced['breeding_behavior'] = 'Live bearer'
            elif 'betta' in fish['common_name'].lower() or 'gourami' in fish['common_name'].lower():
                enhanced['breeding_behavior'] = 'Bubble nester'
        
        # Always set these
        enhanced['last_updated'] = 'NOW()'
        
        return enhanced
    
    async def update_fish_record(self, fish_id: int, fish_name: str, enhanced_attrs: Dict):
        """Update a single fish record with enhanced attributes"""
        try:
            # Clean the attributes (remove None values and convert NOW() function)
            update_data = {}
            for key, value in enhanced_attrs.items():
                if value is not None and key != 'last_updated':
                    update_data[key] = value
            
            # Update the record
            response = self.supabase.table('fish_species').update(update_data).eq('id', fish_id).execute()
            
            if response.data:
                logger.info(f"  ✅ Updated {fish_name}")
                return True
            else:
                logger.warning(f"  ⚠️  No data returned for {fish_name}")
                return False
                
        except Exception as e:
            logger.error(f"  ❌ Failed to update {fish_name}: {str(e)}")
            return False
    
    async def migrate_all_fish(self):
        """Migrate all existing fish to enhanced attribute system"""
        logger.info("🐟 Starting fish data migration to enhanced attributes...")
        
        # Get existing fish
        existing_fish = await self.get_existing_fish()
        if not existing_fish:
            logger.error("No fish data found to migrate")
            return
        
        updated_count = 0
        failed_count = 0
        
        for fish in existing_fish:
            fish_name = fish['common_name']
            fish_id = fish['id']
            
            logger.info(f"Processing: {fish_name}")
            
            # Generate enhanced attributes
            enhanced_attrs = self.generate_enhanced_attributes(fish)
            
            # Update the record
            success = await self.update_fish_record(fish_id, fish_name, enhanced_attrs)
            
            if success:
                updated_count += 1
            else:
                failed_count += 1
        
        logger.info(f"\n🎉 Migration complete!")
        logger.info(f"   ✅ Successfully updated: {updated_count} fish")
        logger.info(f"   ❌ Failed to update: {failed_count} fish")
        logger.info(f"   📊 Total processed: {len(existing_fish)} fish")
    
    async def verify_migration(self):
        """Verify the migration was successful"""
        logger.info("\n🔍 Verifying migration...")
        
        # Check a few sample fish
        sample_fish = ["Blue Tang", "Clownfish", "Betta", "Neon Tetra", "Angelfish"]
        
        for fish_name in sample_fish:
            try:
                response = self.supabase.table('fish_species').select('*').eq('common_name', fish_name).execute()
                
                if response.data:
                    fish = response.data[0]
                    has_enhanced = any(attr in fish for attr in ['temperature_min', 'activity_level', 'fin_vulnerability'])
                    
                    if has_enhanced:
                        logger.info(f"  ✅ {fish_name}: Enhanced attributes present")
                    else:
                        logger.warning(f"  ⚠️  {fish_name}: Missing enhanced attributes")
                else:
                    logger.warning(f"  ❓ {fish_name}: Not found in database")
                    
            except Exception as e:
                logger.error(f"  ❌ Error checking {fish_name}: {str(e)}")

async def main():
    """Run the fish data migration"""
    migrator = FishDataMigrator()
    
    # Run migration
    await migrator.migrate_all_fish()
    
    # Verify results
    await migrator.verify_migration()

if __name__ == "__main__":
    asyncio.run(main())
