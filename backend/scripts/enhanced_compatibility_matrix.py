#!/usr/bin/env python3
"""
Enhanced Compatibility Matrix Generator

Generates compatibility matrix using the enhanced fish attribute system.
Includes comprehensive compatibility analysis and tankmate recommendations.
"""

import asyncio
import json
import logging
import sys
import os
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional
from itertools import combinations

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.supabase_config import get_supabase_client
from app.enhanced_compatibility_integration import (
    check_enhanced_fish_compatibility,
    check_same_species_enhanced,
    get_enhanced_tankmate_compatibility_info
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class EnhancedCompatibilityMatrix:
    """Generate comprehensive compatibility matrix using enhanced attributes"""
    
    def __init__(self):
        self.supabase = get_supabase_client()
        self.compatibility_results = []
        self.tankmate_recommendations = {}
        self.fish_data = {}
        
    async def get_all_fish(self) -> List[Dict]:
        """Get all fish from database"""
        try:
            response = self.supabase.table('fish_species').select('*').execute()
            logger.info(f"Retrieved {len(response.data)} fish species")
            return response.data
        except Exception as e:
            logger.error(f"Failed to retrieve fish data: {str(e)}")
            return []
    
    async def calculate_compatibility_matrix(self):
        """Calculate full compatibility matrix for all fish pairs"""
        logger.info("🧮 Calculating enhanced compatibility matrix...")
        
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
                    # Use enhanced compatibility check
                    compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
                    
                    # Store result
                    result = {
                        'fish1_name': fish1_name,
                        'fish2_name': fish2_name,
                        'compatibility_level': compatibility_level,
                        'reasons': reasons,
                        'conditions': conditions if compatibility_level == 'conditional' else [],
                        'calculated_at': datetime.now(timezone.utc).isoformat(),
                        'method': 'enhanced_attributes'
                    }
                    
                    self.compatibility_results.append(result)
                    
                except Exception as e:
                    logger.error(f"Error processing {fish1_name} + {fish2_name}: {str(e)}")
                    # Store error result
                    result = {
                        'fish1_name': fish1_name,
                        'fish2_name': fish2_name,
                        'compatibility_level': 'unknown',
                        'reasons': [f'Error in compatibility calculation: {str(e)}'],
                        'conditions': [],
                        'calculated_at': datetime.now(timezone.utc).isoformat(),
                        'method': 'error'
                    }
                    self.compatibility_results.append(result)
        
        logger.info(f"✅ Compatibility matrix calculated: {len(self.compatibility_results)} pairs")
    
    async def generate_enhanced_tankmate_recommendations(self):
        """Generate comprehensive tankmate recommendations using enhanced system"""
        logger.info("🐟 Generating enhanced tankmate recommendations...")
        
        for fish_name, fish_data in self.fish_data.items():
            logger.info(f"  Processing recommendations for: {fish_name}")
            
            try:
                # Get enhanced compatibility info
                compatibility_info = get_enhanced_tankmate_compatibility_info(fish_data)
                
                if not compatibility_info.get('allow_tankmates', True):
                    # Highly aggressive fish get no recommendations
                    logger.info(f"    {fish_name}: No tankmates recommended (highly aggressive)")
                    compatible_fish = []
                    conditional_fish = []
                else:
                    # Find compatible and conditional tankmates
                    compatible_fish = []
                    conditional_fish = []
                    
                    for result in self.compatibility_results:
                        # Check if this result involves our target fish
                        other_fish = None
                        if result['fish1_name'] == fish_name:
                            other_fish = result['fish2_name']
                        elif result['fish2_name'] == fish_name:
                            other_fish = result['fish1_name']
                        
                        if other_fish:
                            if result['compatibility_level'] == 'compatible':
                                compatible_fish.append(other_fish)
                            elif result['compatibility_level'] == 'conditional':
                                conditional_fish.append({
                                    'name': other_fish,
                                    'conditions': result['conditions']
                                })
                
                # Combine recommendations (include both compatible and conditional)
                all_tankmates = compatible_fish.copy()
                for cond_fish in conditional_fish:
                    all_tankmates.append(cond_fish['name'])
                
                # Store recommendations
                self.tankmate_recommendations[fish_name] = {
                    'fish_name': fish_name,
                    'fully_compatible_tankmates': compatible_fish,
                    'conditional_tankmates': conditional_fish,
                    'all_recommended_tankmates': all_tankmates,
                    'total_compatible': len(compatible_fish),
                    'total_conditional': len(conditional_fish),
                    'total_recommended': len(all_tankmates),
                    'special_requirements': compatibility_info.get('special_requirements', []),
                    'care_level': compatibility_info.get('care_level', ''),
                    'confidence_score': compatibility_info.get('confidence_score', 0.5),
                    'calculated_at': datetime.now(timezone.utc).isoformat(),
                    'generation_method': 'enhanced_attributes'
                }
                
                logger.info(f"    {fish_name}: {len(compatible_fish)} compatible, {len(conditional_fish)} conditional")
                
            except Exception as e:
                logger.error(f"Error generating recommendations for {fish_name}: {str(e)}")
                # Store minimal recommendation data
                self.tankmate_recommendations[fish_name] = {
                    'fish_name': fish_name,
                    'fully_compatible_tankmates': [],
                    'conditional_tankmates': [],
                    'all_recommended_tankmates': [],
                    'total_compatible': 0,
                    'total_conditional': 0,
                    'total_recommended': 0,
                    'error': str(e),
                    'calculated_at': datetime.now(timezone.utc).isoformat(),
                    'generation_method': 'error'
                }
        
        logger.info(f"✅ Generated recommendations for {len(self.tankmate_recommendations)} fish")
    
    async def save_results_to_database(self):
        """Save compatibility matrix and recommendations to database"""
        logger.info("💾 Saving results to database...")
        
        try:
            # Save compatibility matrix
            logger.info("  Saving compatibility matrix...")
            
            # Clear existing matrix
            self.supabase.table('compatibility_matrix').delete().neq('id', 0).execute()
            
            # Insert new results in batches
            batch_size = 100
            for i in range(0, len(self.compatibility_results), batch_size):
                batch = self.compatibility_results[i:i + batch_size]
                self.supabase.table('compatibility_matrix').insert(batch).execute()
            
            logger.info(f"    ✅ Saved {len(self.compatibility_results)} compatibility pairs")
            
            # Save tankmate recommendations
            logger.info("  Saving tankmate recommendations...")
            
            # Clear existing recommendations
            self.supabase.table('tankmate_recommendations').delete().neq('id', 0).execute()
            
            # Insert new recommendations in batches
            recommendations_list = list(self.tankmate_recommendations.values())
            for i in range(0, len(recommendations_list), batch_size):
                batch = recommendations_list[i:i + batch_size]
                self.supabase.table('tankmate_recommendations').insert(batch).execute()
            
            logger.info(f"    ✅ Saved {len(recommendations_list)} tankmate recommendations")
            
        except Exception as e:
            logger.error(f"Failed to save results to database: {str(e)}")
    
    async def save_results_to_files(self):
        """Save results to local JSON files for backup"""
        logger.info("💾 Saving results to local files...")
        
        try:
            # Save compatibility matrix
            matrix_file = 'enhanced_compatibility_matrix.json'
            with open(matrix_file, 'w') as f:
                json.dump(self.compatibility_results, f, indent=2)
            logger.info(f"    ✅ Saved compatibility matrix to {matrix_file}")
            
            # Save tankmate recommendations
            recommendations_file = 'enhanced_tankmate_recommendations.json'
            with open(recommendations_file, 'w') as f:
                json.dump(self.tankmate_recommendations, f, indent=2)
            logger.info(f"    ✅ Saved recommendations to {recommendations_file}")
            
            # Generate summary report
            summary = {
                'generation_date': datetime.now(timezone.utc).isoformat(),
                'total_fish_species': len(self.fish_data),
                'total_compatibility_pairs': len(self.compatibility_results),
                'total_tankmate_recommendations': len(self.tankmate_recommendations),
                'compatibility_distribution': {
                    'compatible': len([r for r in self.compatibility_results if r['compatibility_level'] == 'compatible']),
                    'conditional': len([r for r in self.compatibility_results if r['compatibility_level'] == 'conditional']),
                    'incompatible': len([r for r in self.compatibility_results if r['compatibility_level'] == 'incompatible']),
                    'unknown': len([r for r in self.compatibility_results if r['compatibility_level'] == 'unknown'])
                },
                'method': 'enhanced_attributes',
                'system_version': '2.0'
            }
            
            summary_file = 'enhanced_compatibility_summary.json'
            with open(summary_file, 'w') as f:
                json.dump(summary, f, indent=2)
            logger.info(f"    ✅ Saved summary to {summary_file}")
            
        except Exception as e:
            logger.error(f"Failed to save results to files: {str(e)}")
    
    async def generate_full_matrix(self):
        """Generate complete enhanced compatibility matrix and recommendations"""
        logger.info("🚀 Starting enhanced compatibility matrix generation...")
        
        start_time = datetime.now()
        
        # Step 1: Calculate compatibility matrix
        await self.calculate_compatibility_matrix()
        
        # Step 2: Generate tankmate recommendations
        await self.generate_enhanced_tankmate_recommendations()
        
        # Step 3: Save to database
        await self.save_results_to_database()
        
        # Step 4: Save to files
        await self.save_results_to_files()
        
        end_time = datetime.now()
        duration = end_time - start_time
        
        logger.info(f"🎉 Enhanced compatibility matrix generation complete!")
        logger.info(f"   Duration: {duration}")
        logger.info(f"   Fish species: {len(self.fish_data)}")
        logger.info(f"   Compatibility pairs: {len(self.compatibility_results)}")
        logger.info(f"   Tankmate recommendations: {len(self.tankmate_recommendations)}")

async def main():
    """Generate enhanced compatibility matrix"""
    matrix_generator = EnhancedCompatibilityMatrix()
    await matrix_generator.generate_full_matrix()

if __name__ == "__main__":
    asyncio.run(main())
