#!/usr/bin/env python3
"""
Fish Compatibility Matrix Generator

This script pre-calculates compatibility between all fish pairs in the database
and stores the results in Supabase for quick retrieval in the mobile app.

It also generates tankmate recommendations for each fish species.
"""

import os
import sys
import json
import asyncio
from typing import List, Dict, Tuple, Set
from datetime import datetime, timezone
import logging

# Add the parent directory to the path to import from app module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.supabase_config import get_supabase_client
from app.conditional_compatibility import check_conditional_compatibility, check_pairwise_compatibility
from app.compatibility_logic import can_same_species_coexist
from itertools import combinations

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CompatibilityMatrixGenerator:
    def __init__(self):
        self.supabase = get_supabase_client()
        self.fish_data = {}
        self.compatibility_results = []
        self.tankmate_recommendations = {}
        
    async def load_fish_data(self) -> Dict[str, Dict]:
        """Load all fish species data from Supabase"""
        logger.info("Loading fish species data from Supabase...")
        
        try:
            response = self.supabase.table('fish_species').select('*').execute()
            fish_list = response.data
            
            # Convert to dictionary for easier access
            for fish in fish_list:
                common_name = fish.get('common_name', '').strip()
                if common_name:
                    self.fish_data[common_name] = fish
            
            logger.info(f"Loaded {len(self.fish_data)} fish species")
            return self.fish_data
            
        except Exception as e:
            logger.error(f"Error loading fish data: {e}")
            raise
    
    def calculate_compatibility(self, fish1_name: str, fish2_name: str) -> Tuple[str, List[str], List[str]]:
        """Calculate compatibility between two fish species"""
        fish1 = self.fish_data.get(fish1_name)
        fish2 = self.fish_data.get(fish2_name)
        
        if not fish1 or not fish2:
            return "incompatible", [f"Fish data not found for {fish1_name} or {fish2_name}"], []
        
        # Check if same species
        if fish1_name.lower() == fish2_name.lower():
            is_compatible, reason = can_same_species_coexist(fish1_name, fish1)
            if not is_compatible:
                return "incompatible", [reason], []
            else:
                return "compatible", [], []
        
        # Check different species compatibility with conditional support
        return check_conditional_compatibility(fish1, fish2)
    
    async def generate_compatibility_matrix(self):
        """Generate compatibility matrix for all fish pairs"""
        logger.info("Generating compatibility matrix...")
        
        fish_names = list(self.fish_data.keys())
        total_pairs = len(list(combinations(fish_names, 2))) + len(fish_names)  # pairs + self-compatibility
        processed = 0
        
        # Check all unique pairs
        for fish1_name, fish2_name in combinations(fish_names, 2):
            compatibility_level, reasons, conditions = self.calculate_compatibility(fish1_name, fish2_name)
            is_compatible = compatibility_level in ["compatible", "conditional"]
            
            compatibility_record = {
                'fish1_name': fish1_name,
                'fish2_name': fish2_name,
                'is_compatible': is_compatible,
                'compatibility_level': compatibility_level,
                'reasons': reasons,
                'conditions': conditions,
                'calculated_at': datetime.now(timezone.utc).isoformat(),
                'compatibility_score': 1.0 if compatibility_level == "compatible" else 0.5 if compatibility_level == "conditional" else 0.0
            }
            
            self.compatibility_results.append(compatibility_record)
            processed += 1
            
            if processed % 100 == 0:
                logger.info(f"Processed {processed}/{total_pairs} pairs ({processed/total_pairs*100:.1f}%)")
        
        # Check self-compatibility (same species)
        for fish_name in fish_names:
            compatibility_level, reasons, conditions = self.calculate_compatibility(fish_name, fish_name)
            is_compatible = compatibility_level in ["compatible", "conditional"]
            
            compatibility_record = {
                'fish1_name': fish_name,
                'fish2_name': fish_name,
                'is_compatible': is_compatible,
                'compatibility_level': compatibility_level,
                'reasons': reasons,
                'conditions': conditions,
                'calculated_at': datetime.now(timezone.utc).isoformat(),
                'compatibility_score': 1.0 if compatibility_level == "compatible" else 0.5 if compatibility_level == "conditional" else 0.0
            }
            
            self.compatibility_results.append(compatibility_record)
            processed += 1
        
        logger.info(f"Generated {len(self.compatibility_results)} compatibility records")
    
    def generate_tankmate_recommendations(self):
        """Generate tankmate recommendations for each fish species"""
        logger.info("Generating tankmate recommendations...")
        
        for fish_name in self.fish_data.keys():
            compatible_fish = []
            conditional_fish = []
            
            # Check if this is a highly aggressive fish that should have no tankmate recommendations
            fish_name_lower = fish_name.lower()
            highly_aggressive_fish = [
                "betta", "siamese fighting fish", "paradise fish", 
                "flowerhorn", "wolf cichlid", "jaguar cichlid",
                "red devil", "midas cichlid", "texas cichlid"
            ]
            is_highly_aggressive = any(aggressive_fish in fish_name_lower for aggressive_fish in highly_aggressive_fish)
            
            if is_highly_aggressive:
                # Highly aggressive fish get no tankmate recommendations
                all_tankmates = []
            else:
                # For other fish, include both compatible and conditional
                for result in self.compatibility_results:
                    if result['compatibility_level'] == 'compatible':
                        if result['fish1_name'] == fish_name and result['fish2_name'] != fish_name:
                            compatible_fish.append(result['fish2_name'])
                        elif result['fish2_name'] == fish_name and result['fish1_name'] != fish_name:
                            compatible_fish.append(result['fish1_name'])
                    elif result['compatibility_level'] == 'conditional':
                        if result['fish1_name'] == fish_name and result['fish2_name'] != fish_name:
                            conditional_fish.append(result['fish2_name'])
                        elif result['fish2_name'] == fish_name and result['fish1_name'] != fish_name:
                            conditional_fish.append(result['fish1_name'])
                
                # Remove duplicates and sort
                compatible_fish = sorted(list(set(compatible_fish)))
                conditional_fish = sorted(list(set(conditional_fish)))
                
                # Combine both lists for total tankmate recommendations
                all_tankmates = compatible_fish + conditional_fish
            
            self.tankmate_recommendations[fish_name] = {
                'fish_name': fish_name,
                'compatible_tankmates': all_tankmates,
                'total_compatible': len(all_tankmates),
                'calculated_at': datetime.now(timezone.utc).isoformat()
            }
        
        logger.info(f"Generated tankmate recommendations for {len(self.tankmate_recommendations)} fish species")
    
    async def create_tables_if_not_exist(self):
        """Create the necessary tables in Supabase if they don't exist"""
        logger.info("Ensuring required tables exist...")
        
        # Note: In practice, you should create these tables through Supabase dashboard or migrations
        # This is just for reference of the expected schema
        
        compatibility_table_schema = """
        CREATE TABLE IF NOT EXISTS fish_compatibility (
            id SERIAL PRIMARY KEY,
            fish1_name TEXT NOT NULL,
            fish2_name TEXT NOT NULL,
            is_compatible BOOLEAN NOT NULL,
            reasons TEXT[] NOT NULL,
            compatibility_score FLOAT DEFAULT 0.0,
            calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(fish1_name, fish2_name)
        );
        """
        
        tankmates_table_schema = """
        CREATE TABLE IF NOT EXISTS fish_tankmate_recommendations (
            id SERIAL PRIMARY KEY,
            fish_name TEXT NOT NULL UNIQUE,
            compatible_tankmates TEXT[] NOT NULL,
            total_compatible INTEGER NOT NULL,
            calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        logger.info("Tables should be created manually in Supabase dashboard with the following schemas:")
        logger.info("Fish Compatibility Table:")
        logger.info(compatibility_table_schema)
        logger.info("Tankmate Recommendations Table:")
        logger.info(tankmates_table_schema)
    
    async def save_to_supabase(self):
        """Save compatibility results and tankmate recommendations to Supabase"""
        logger.info("Saving results to Supabase...")
        
        try:
            # Clear existing data
            logger.info("Clearing existing compatibility data...")
            self.supabase.table('fish_compatibility').delete().neq('id', 0).execute()
            
            logger.info("Clearing existing tankmate recommendations...")
            self.supabase.table('fish_tankmate_recommendations').delete().neq('id', 0).execute()
            
            # Insert compatibility data in batches
            batch_size = 100
            total_batches = (len(self.compatibility_results) + batch_size - 1) // batch_size
            
            for i in range(0, len(self.compatibility_results), batch_size):
                batch = self.compatibility_results[i:i + batch_size]
                batch_num = i // batch_size + 1
                
                logger.info(f"Inserting compatibility batch {batch_num}/{total_batches}")
                response = self.supabase.table('fish_compatibility').insert(batch).execute()
                
                if not response.data:
                    logger.warning(f"No data returned for batch {batch_num}")
            
            # Insert tankmate recommendations
            tankmate_list = list(self.tankmate_recommendations.values())
            total_batches = (len(tankmate_list) + batch_size - 1) // batch_size
            
            for i in range(0, len(tankmate_list), batch_size):
                batch = tankmate_list[i:i + batch_size]
                batch_num = i // batch_size + 1
                
                logger.info(f"Inserting tankmate batch {batch_num}/{total_batches}")
                response = self.supabase.table('fish_tankmate_recommendations').insert(batch).execute()
                
                if not response.data:
                    logger.warning(f"No data returned for tankmate batch {batch_num}")
            
            logger.info("Successfully saved all data to Supabase")
            
        except Exception as e:
            logger.error(f"Error saving to Supabase: {e}")
            raise
    
    async def generate_report(self):
        """Generate a summary report of the compatibility analysis"""
        logger.info("Generating compatibility report...")
        
        total_pairs = len(self.compatibility_results)
        compatible_pairs = sum(1 for r in self.compatibility_results if r['is_compatible'])
        incompatible_pairs = total_pairs - compatible_pairs
        
        # Find most compatible fish (those with most tankmates)
        most_compatible = sorted(
            self.tankmate_recommendations.values(),
            key=lambda x: x['total_compatible'],
            reverse=True
        )[:10]
        
        # Find least compatible fish
        least_compatible = sorted(
            self.tankmate_recommendations.values(),
            key=lambda x: x['total_compatible']
        )[:10]
        
        report = {
            'summary': {
                'total_fish_species': len(self.fish_data),
                'total_compatibility_pairs': total_pairs,
                'compatible_pairs': compatible_pairs,
                'incompatible_pairs': incompatible_pairs,
                'compatibility_percentage': (compatible_pairs / total_pairs * 100) if total_pairs > 0 else 0
            },
            'most_compatible_fish': [
                {
                    'name': fish['fish_name'],
                    'compatible_count': fish['total_compatible']
                } for fish in most_compatible
            ],
            'least_compatible_fish': [
                {
                    'name': fish['fish_name'],
                    'compatible_count': fish['total_compatible']
                } for fish in least_compatible
            ],
            'generated_at': datetime.now(timezone.utc).isoformat()
        }
        
        # Save report to file
        report_file = 'scripts/compatibility_report.json'
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Compatibility report saved to {report_file}")
        logger.info(f"Summary: {compatible_pairs}/{total_pairs} pairs are compatible ({report['summary']['compatibility_percentage']:.1f}%)")
        
        return report
    
    async def run(self):
        """Run the complete compatibility matrix generation process"""
        try:
            logger.info("Starting fish compatibility matrix generation...")
            
            # Load fish data
            await self.load_fish_data()
            
            if not self.fish_data:
                logger.error("No fish data loaded. Exiting.")
                return
            
            # Ensure tables exist
            await self.create_tables_if_not_exist()
            
            # Generate compatibility matrix
            await self.generate_compatibility_matrix()
            
            # Generate tankmate recommendations
            self.generate_tankmate_recommendations()
            
            # Save to Supabase
            await self.save_to_supabase()
            
            # Generate report
            await self.generate_report()
            
            logger.info("Fish compatibility matrix generation completed successfully!")
            
        except Exception as e:
            logger.error(f"Error during compatibility matrix generation: {e}")
            raise

async def main():
    """Main function to run the compatibility matrix generator"""
    generator = CompatibilityMatrixGenerator()
    await generator.run()

if __name__ == "__main__":
    asyncio.run(main())
