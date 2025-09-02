#!/usr/bin/env python3
"""
Fix Tankmate Recommendations Script

This script fixes the fish_tankmate_recommendations table by:
1. Using the improved table structure
2. Implementing more realistic compatibility logic
3. Regenerating accurate tankmate recommendations
4. Separating fully compatible, conditional, and incompatible fish
"""

import asyncio
import json
import logging
import sys
import os
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional, Tuple
from itertools import combinations

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.supabase_config import get_supabase_client
from app.enhanced_compatibility_integration import (
    check_enhanced_fish_compatibility,
    get_enhanced_tankmate_compatibility_info
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class TankmateRecommendationsFixer:
    """Fix and regenerate tankmate recommendations with improved logic"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
        self.compatibility_matrix = []
        self.tankmate_recommendations = {}
        self.fish_data = {}
        
        # Known problematic fish combinations for manual fixes
        self.manual_compatibility_fixes = self._load_manual_fixes()
    
    def _load_manual_fixes(self) -> Dict[str, Dict]:
        """Load manually curated compatibility fixes for known problematic combinations"""
        return {
            # Betta fish - very specific compatibility requirements
            "betta": {
                "fully_compatible": [
                    "corydoras", "kuhli loach", "otocinclus", "mystery snail", 
                    "nerite snail", "cherry shrimp", "ghost shrimp"
                ],
                "conditional": [
                    "neon tetra", "ember tetra", "harlequin rasbora", 
                    "celestial pearl danio", "white cloud mountain minnow"
                ],
                "incompatible": [
                    "guppy", "platy", "swordtail", "molly", "angelfish",
                    "tiger barb", "serpae tetra", "other betta", "paradise fish"
                ],
                "conditions": {
                    "neon tetra": ["20+ gallon tank", "Peaceful temperament only", "Monitor for fin nipping"],
                    "ember tetra": ["20+ gallon tank", "Peaceful temperament only", "Monitor for fin nipping"],
                    "harlequin rasbora": ["20+ gallon tank", "Peaceful temperament only", "Monitor for fin nipping"]
                }
            },
            
            # Flowerhorn - highly aggressive, very limited compatibility
            "flowerhorn": {
                "fully_compatible": [],
                "conditional": [
                    "oscar", "jack dempsey", "texas cichlid", "green terror",
                    "electric blue jack dempsey", "common pleco", "bristlenose pleco"
                ],
                "incompatible": [
                    "guppy", "neon tetra", "corydoras", "angelfish", "molly",
                    "platy", "swordtail", "betta", "peaceful fish"
                ],
                "conditions": {
                    "oscar": ["75+ gallon tank per fish", "Monitor for aggression", "Be prepared to separate"],
                    "jack dempsey": ["75+ gallon tank per fish", "Monitor for aggression", "Be prepared to separate"],
                    "common pleco": ["75+ gallon tank", "Large size only", "Monitor for aggression"]
                }
            },
            
            # Goldfish - specific requirements
            "goldfish": {
                "fully_compatible": [
                    "other goldfish", "white cloud mountain minnow", "rosy barb",
                    "dojo loach", "weather loach"
                ],
                "conditional": [
                    "bristlenose pleco", "rubber lip pleco", "hillstream loach"
                ],
                "incompatible": [
                    "tropical fish", "betta", "angelfish", "guppy", "molly",
                    "neon tetra", "corydoras", "tiger barb"
                ],
                "conditions": {
                    "bristlenose pleco": ["Cold water only", "Large tank", "Monitor temperature"],
                    "rubber lip pleco": ["Cold water only", "Large tank", "Monitor temperature"]
                }
            },
            
            # Marine fish - saltwater only
            "blue tang": {
                "fully_compatible": [
                    "clownfish", "damselfish", "royal gramma", "firefish",
                    "cardinalfish", "wrasse", "goby"
                ],
                "conditional": [
                    "other tangs", "angelfish", "butterflyfish"
                ],
                "incompatible": [
                    "freshwater fish", "brackish fish", "betta", "guppy", "molly"
                ],
                "conditions": {
                    "other tangs": ["Large tank (100+ gallons)", "Different species only", "Monitor for aggression"],
                    "angelfish": ["Large tank", "Different tank zones", "Monitor for aggression"]
                }
            },
            
            # Aggressive cichlids
            "oscar": {
                "fully_compatible": [
                    "other oscars", "jack dempsey", "texas cichlid", "green terror",
                    "firemouth cichlid", "convict cichlid"
                ],
                "conditional": [
                    "common pleco", "bristlenose pleco", "silver dollar", "tinfoil barb"
                ],
                "incompatible": [
                    "small fish", "peaceful fish", "betta", "guppy", "neon tetra",
                    "angelfish", "molly", "platy"
                ],
                "conditions": {
                    "common pleco": ["Large tank", "Large size only", "Monitor for aggression"],
                    "silver dollar": ["Large tank", "School of 6+", "Monitor for aggression"]
                }
            }
        }
    
    async def get_all_fish(self) -> List[Dict]:
        """Get all fish from database"""
        try:
            response = self.supabase.table('fish_species').select('*').execute()
            logger.info(f"Retrieved {len(response.data)} fish species")
            return response.data
        except Exception as e:
            logger.error(f"Failed to retrieve fish data: {str(e)}")
            return []
    
    def check_manual_compatibility(self, fish1_name: str, fish2_name: str) -> Optional[Tuple[str, List[str], List[str]]]:
        """Check if there's a manual compatibility rule for this fish pair"""
        fish1_lower = fish1_name.lower()
        fish2_lower = fish2_name.lower()
        
        # Check if either fish has manual rules
        for fish_key, rules in self.manual_compatibility_fixes.items():
            if fish_key in fish1_lower or fish_key in fish2_lower:
                # Determine which fish is the reference fish
                if fish_key in fish1_lower:
                    reference_fish = fish1_name
                    other_fish = fish2_name
                    other_fish_lower = fish2_lower
                else:
                    reference_fish = fish2_name
                    other_fish = fish1_name
                    other_fish_lower = fish1_lower
                
                # Check compatibility based on manual rules
                if other_fish_lower in rules["fully_compatible"]:
                    return ("compatible", 
                           [f"{reference_fish} is fully compatible with {other_fish}"],
                           [])
                
                elif other_fish_lower in rules["conditional"]:
                    conditions = rules["conditions"].get(other_fish_lower, [])
                    return ("conditional",
                           [f"{reference_fish} can be housed with {other_fish} under specific conditions"],
                           conditions)
                
                elif other_fish_lower in rules["incompatible"]:
                    return ("incompatible",
                           [f"{reference_fish} is not compatible with {other_fish}"],
                           [])
        
        return None  # No manual rule found
    
    def check_enhanced_compatibility_realistic(self, fish1: Dict, fish2: Dict) -> Tuple[str, List[str], List[str]]:
        """Check compatibility using enhanced system with realistic aquarium logic"""
        
        # First check manual compatibility rules
        manual_result = self.check_manual_compatibility(fish1['common_name'], fish2['common_name'])
        if manual_result:
            return manual_result
        
        # Use enhanced compatibility system
        try:
            compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
            return compatibility_level, reasons, conditions
        except Exception as e:
            logger.error(f"Enhanced compatibility check failed: {str(e)}")
            # Fall back to basic compatibility check
            return self._basic_compatibility_check(fish1, fish2)
    
    def _basic_compatibility_check(self, fish1: Dict, fish2: Dict) -> Tuple[str, List[str], List[str]]:
        """Basic compatibility check as fallback"""
        fish1_name = fish1['common_name']
        fish2_name = fish2['common_name']
        
        # Check water type compatibility
        water1 = str(fish1.get('water_type', '')).lower()
        water2 = str(fish2.get('water_type', '')).lower()
        
        if water1 != water2:
            if 'saltwater' in water1 and 'freshwater' in water2:
                return ("incompatible", 
                       [f"{fish1_name} (saltwater) cannot live with {fish2_name} (freshwater)"],
                       [])
            elif 'freshwater' in water1 and 'saltwater' in water2:
                return ("incompatible", 
                       [f"{fish1_name} (freshwater) cannot live with {fish2_name} (saltwater)"],
                       [])
        
        # Check temperament compatibility
        temperament1 = str(fish1.get('temperament', '')).lower()
        temperament2 = str(fish2.get('temperament', '')).lower()
        
        if 'aggressive' in temperament1 and 'peaceful' in temperament2:
            return ("incompatible",
                   [f"{fish1_name} (aggressive) will harm {fish2_name} (peaceful)"],
                   [])
        
        if 'aggressive' in temperament2 and 'peaceful' in temperament1:
            return ("incompatible",
                   [f"{fish2_name} (aggressive) will harm {fish1_name} (peaceful)"],
                   [])
        
        # Check size compatibility
        size1 = float(fish1.get('max_size_(cm)', 0) or 0)
        size2 = float(fish2.get('max_size_(cm)', 0) or 0)
        
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio > 4:  # Significant size difference
                if 'peaceful' in temperament1 and 'peaceful' in temperament2:
                    return ("conditional",
                           [f"{fish1_name} and {fish2_name} have significant size difference"],
                           ["Monitor for bullying", "Provide hiding spots", "Ensure adequate tank size"])
        
        # Default to conditional if no major issues found
        return ("conditional",
               [f"{fish1_name} and {fish2_name} may be compatible with proper care"],
               ["Monitor behavior", "Provide adequate space", "Ensure proper water parameters"])
    
    async def calculate_compatibility_matrix(self):
        """Calculate full compatibility matrix for all fish pairs"""
        logger.info("🧮 Calculating realistic compatibility matrix...")
        
        # Get all fish
        all_fish = await self.get_all_fish()
        if not all_fish:
            logger.error("No fish data found")
            return
        
        # Store fish data for reference
        for fish in all_fish:
            self.fish_data[fish['common_name']] = fish
        
        # Calculate all pairwise combinations
        total_pairs = len(all_fish) * (len(all_fish) - 1) // 2
        processed = 0
        
        logger.info(f"Processing {total_pairs} fish pairs...")
        
        for i, fish1 in enumerate(all_fish):
            for j, fish2 in enumerate(all_fish):
                if i >= j:  # Skip duplicate pairs and self-pairs
                    continue
                
                processed += 1
                if processed % 100 == 0:
                    logger.info(f"  Progress: {processed}/{total_pairs} pairs processed")
                
                fish1_name = fish1['common_name']
                fish2_name = fish2['common_name']
                
                try:
                    # Use realistic compatibility check
                    compatibility_level, reasons, conditions = self.check_enhanced_compatibility_realistic(fish1, fish2)
                    
                    # Determine if compatible (including conditional)
                    is_compatible = compatibility_level in ['compatible', 'conditional']
                    
                    # Store result
                    result = {
                        'fish1_name': fish1_name,
                        'fish2_name': fish2_name,
                        'compatibility_level': compatibility_level,
                        'is_compatible': is_compatible,
                        'compatibility_reasons': reasons,
                        'conditions': conditions if compatibility_level == 'conditional' else [],
                        'compatibility_score': 1.0 if compatibility_level == 'compatible' else 0.5 if compatibility_level == 'conditional' else 0.0,
                        'confidence_score': 0.8,  # High confidence for manual rules
                        'generation_method': 'enhanced_attributes',
                        'calculated_at': datetime.now(timezone.utc).isoformat()
                    }
                    
                    self.compatibility_matrix.append(result)
                    
                except Exception as e:
                    logger.error(f"Error processing {fish1_name} + {fish2_name}: {str(e)}")
                    # Store error result
                    result = {
                        'fish1_name': fish1_name,
                        'fish2_name': fish2_name,
                        'compatibility_level': 'unknown',
                        'is_compatible': False,
                        'compatibility_reasons': [f'Error in compatibility calculation: {str(e)}'],
                        'conditions': [],
                        'compatibility_score': 0.0,
                        'confidence_score': 0.0,
                        'generation_method': 'error',
                        'calculated_at': datetime.now(timezone.utc).isoformat()
                    }
                    self.compatibility_matrix.append(result)
        
        logger.info(f"✅ Compatibility matrix calculated: {len(self.compatibility_matrix)} pairs")
    
    async def generate_improved_tankmate_recommendations(self):
        """Generate improved tankmate recommendations with separate compatibility levels"""
        logger.info("🐟 Generating improved tankmate recommendations...")
        
        for fish_name, fish_data in self.fish_data.items():
            logger.info(f"  Processing recommendations for: {fish_name}")
            
            try:
                # Get enhanced compatibility info
                compatibility_info = get_enhanced_tankmate_compatibility_info(fish_data)
                
                # Find compatible and conditional tankmates from matrix
                fully_compatible = []
                conditional_tankmates = []
                incompatible = []
                
                for result in self.compatibility_matrix:
                    # Check if this result involves our target fish
                    other_fish = None
                    if result['fish1_name'] == fish_name:
                        other_fish = result['fish2_name']
                    elif result['fish2_name'] == fish_name:
                        other_fish = result['fish1_name']
                    
                    if other_fish:
                        if result['compatibility_level'] == 'compatible':
                            fully_compatible.append(other_fish)
                        elif result['compatibility_level'] == 'conditional':
                            conditional_tankmates.append({
                                'name': other_fish,
                                'conditions': result['conditions']
                            })
                        elif result['compatibility_level'] == 'incompatible':
                            incompatible.append(other_fish)
                
                # Store recommendations with improved structure
                self.tankmate_recommendations[fish_name] = {
                    'fish_name': fish_name,
                    'fully_compatible_tankmates': fully_compatible,
                    'conditional_tankmates': conditional_tankmates,
                    'incompatible_tankmates': incompatible,
                    'total_fully_compatible': len(fully_compatible),
                    'total_conditional': len(conditional_tankmates),
                    'total_incompatible': len(incompatible),
                    'total_recommended': len(fully_compatible) + len(conditional_tankmates),
                    'special_requirements': compatibility_info.get('special_requirements', []),
                    'care_level': compatibility_info.get('care_level', ''),
                    'confidence_score': compatibility_info.get('confidence_score', 0.5),
                    'generation_method': 'enhanced_attributes',
                    'calculated_at': datetime.now(timezone.utc).isoformat()
                }
                
                logger.info(f"    {fish_name}: {len(fully_compatible)} fully compatible, {len(conditional_tankmates)} conditional")
                
            except Exception as e:
                logger.error(f"Error generating recommendations for {fish_name}: {str(e)}")
                # Store minimal recommendation data
                self.tankmate_recommendations[fish_name] = {
                    'fish_name': fish_name,
                    'fully_compatible_tankmates': [],
                    'conditional_tankmates': [],
                    'incompatible_tankmates': [],
                    'total_fully_compatible': 0,
                    'total_conditional': 0,
                    'total_incompatible': 0,
                    'total_recommended': 0,
                    'special_requirements': [],
                    'care_level': '',
                    'confidence_score': 0.0,
                    'generation_method': 'error',
                    'calculated_at': datetime.now(timezone.utc).isoformat()
                }
        
        logger.info(f"✅ Generated recommendations for {len(self.tankmate_recommendations)} fish")
    
    async def save_to_database(self):
        """Save compatibility matrix and recommendations to database"""
        logger.info("💾 Saving results to database...")
        
        try:
            # Save compatibility matrix
            logger.info("  Saving compatibility matrix...")
            
            # Clear existing matrix
            self.supabase.table('fish_compatibility_matrix').delete().neq('id', 0).execute()
            
            # Insert new results in batches
            batch_size = 100
            for i in range(0, len(self.compatibility_matrix), batch_size):
                batch = self.compatibility_matrix[i:i + batch_size]
                self.supabase.table('fish_compatibility_matrix').insert(batch).execute()
            
            logger.info(f"    ✅ Saved {len(self.compatibility_matrix)} compatibility pairs")
            
            # Save tankmate recommendations
            logger.info("  Saving tankmate recommendations...")
            
            # Clear existing recommendations
            self.supabase.table('fish_tankmate_recommendations').delete().neq('id', 0).execute()
            
            # Insert new recommendations in batches
            recommendations_list = list(self.tankmate_recommendations.values())
            for i in range(0, len(recommendations_list), batch_size):
                batch = recommendations_list[i:i + batch_size]
                self.supabase.table('fish_tankmate_recommendations').insert(batch).execute()
            
            logger.info(f"    ✅ Saved {len(recommendations_list)} tankmate recommendations")
            
        except Exception as e:
            logger.error(f"Failed to save results to database: {str(e)}")
    
    async def save_to_files(self):
        """Save results to local JSON files for backup"""
        logger.info("💾 Saving results to local files...")
        
        try:
            # Save compatibility matrix
            matrix_file = 'fixed_compatibility_matrix.json'
            with open(matrix_file, 'w') as f:
                json.dump(self.compatibility_matrix, f, indent=2)
            logger.info(f"    ✅ Saved compatibility matrix to {matrix_file}")
            
            # Save tankmate recommendations
            recommendations_file = 'fixed_tankmate_recommendations.json'
            with open(recommendations_file, 'w') as f:
                json.dump(self.tankmate_recommendations, f, indent=2)
            logger.info(f"    ✅ Saved recommendations to {recommendations_file}")
            
            # Generate summary report
            summary = {
                'generation_date': datetime.now(timezone.utc).isoformat(),
                'total_fish_species': len(self.fish_data),
                'total_compatibility_pairs': len(self.compatibility_matrix),
                'total_tankmate_recommendations': len(self.tankmate_recommendations),
                'compatibility_distribution': {
                    'compatible': len([r for r in self.compatibility_matrix if r['compatibility_level'] == 'compatible']),
                    'conditional': len([r for r in self.compatibility_matrix if r['compatibility_level'] == 'conditional']),
                    'incompatible': len([r for r in self.compatibility_matrix if r['compatibility_level'] == 'incompatible']),
                    'unknown': len([r for r in self.compatibility_matrix if r['compatibility_level'] == 'unknown'])
                },
                'method': 'enhanced_attributes_with_manual_fixes',
                'system_version': '2.1_fixed'
            }
            
            summary_file = 'fixed_compatibility_summary.json'
            with open(summary_file, 'w') as f:
                json.dump(summary, f, indent=2)
            logger.info(f"    ✅ Saved summary to {summary_file}")
            
        except Exception as e:
            logger.error(f"Failed to save results to files: {str(e)}")
    
    async def fix_tankmate_recommendations(self):
        """Main method to fix tankmate recommendations"""
        logger.info("🚀 Starting tankmate recommendations fix...")
        
        start_time = datetime.now()
        
        # Step 1: Calculate compatibility matrix
        await self.calculate_compatibility_matrix()
        
        # Step 2: Generate improved tankmate recommendations
        await self.generate_improved_tankmate_recommendations()
        
        # Step 3: Save to database
        await self.save_to_database()
        
        # Step 4: Save to files
        await self.save_to_files()
        
        end_time = datetime.now()
        duration = end_time - start_time
        
        logger.info(f"🎉 Tankmate recommendations fix complete!")
        logger.info(f"   Duration: {duration}")
        logger.info(f"   Fish species: {len(self.fish_data)}")
        logger.info(f"   Compatibility pairs: {len(self.compatibility_matrix)}")
        logger.info(f"   Tankmate recommendations: {len(self.tankmate_recommendations)}")

async def main():
    """Fix tankmate recommendations"""
    fixer = TankmateRecommendationsFixer()
    await fixer.fix_tankmate_recommendations()

if __name__ == "__main__":
    asyncio.run(main())
