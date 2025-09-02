#!/usr/bin/env python3
"""
Simplified Fish Data Scraper for Compatibility Analysis

Focuses only on the essential fields needed for fish compatibility checking:
- water_type (Freshwater/Saltwater/Brackish)
- temperament (Peaceful/Semi-aggressive/Aggressive)  
- social_behavior (Community/Schooling/Pairs/Solitary)
- max_size_(cm) (for size difference calculations)
- minimum_tank_size_l (for tank requirements)
- diet (Herbivore/Carnivore/Omnivore)
"""

import asyncio
import aiohttp
import json
import logging
import re
from typing import Dict, List, Optional
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.supabase_config import get_supabase_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SimpleFishScraper:
    """Focused scraper for essential compatibility data"""
    
    def __init__(self):
        self.api_url = "https://en.wikipedia.org/w/api.php"
        self.supabase = get_supabase_client()
        
    async def scrape_and_fix_fish_data(self, fish_names: List[str]) -> Dict[str, Dict]:
        """Scrape essential compatibility data and update database"""
        
        async with aiohttp.ClientSession() as session:
            results = {}
            
            for fish_name in fish_names:
                logger.info(f"Processing: {fish_name}")
                
                # First get current database data
                current_data = await self._get_current_data(fish_name)
                
                # Scrape fresh data from Wikipedia
                scraped_data = await self._scrape_wikipedia_essential(session, fish_name)
                
                # Merge and fix data
                fixed_data = self._merge_and_fix_data(current_data, scraped_data, fish_name)
                
                if fixed_data:
                    results[fish_name] = fixed_data
                    # Update database immediately
                    await self._update_database(fish_name, fixed_data)
                
                await asyncio.sleep(1)  # Rate limiting
            
            return results
    
    async def _get_current_data(self, fish_name: str) -> Dict:
        """Get current data from database"""
        try:
            response = self.supabase.table('fish_species').select('*').ilike('common_name', fish_name).execute()
            return response.data[0] if response.data else {}
        except:
            return {}
    
    async def _scrape_wikipedia_essential(self, session: aiohttp.ClientSession, fish_name: str) -> Dict:
        """Scrape only essential fields from Wikipedia"""
        
        # Find Wikipedia page
        page_title = await self._find_wikipedia_page(session, fish_name)
        if not page_title:
            return {}
        
        # Get page content
        content = await self._get_page_content(session, page_title)
        if not content:
            return {}
        
        # Extract only essential fields
        return self._extract_essential_data(content, fish_name)
    
    async def _find_wikipedia_page(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[str]:
        """Find Wikipedia page for fish"""
        
        search_terms = [fish_name, f"{fish_name} fish"]
        
        for term in search_terms:
            params = {
                'action': 'query',
                'format': 'json',
                'list': 'search',
                'srsearch': term,
                'srlimit': 3
            }
            
            try:
                async with session.get(self.api_url, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        results = data.get('query', {}).get('search', [])
                        
                        for result in results:
                            title = result['title']
                            snippet = result['snippet'].lower()
                            
                            # Check if this looks like a fish article
                            if any(word in snippet for word in ['fish', 'species', 'aquarium', 'marine', 'freshwater']):
                                return title
            except:
                continue
        
        return None
    
    async def _get_page_content(self, session: aiohttp.ClientSession, page_title: str) -> Optional[str]:
        """Get Wikipedia page content"""
        
        params = {
            'action': 'query',
            'format': 'json',
            'titles': page_title,
            'prop': 'extracts',
            'explaintext': True,
            'exsectionformat': 'plain'
        }
        
        try:
            async with session.get(self.api_url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    pages = data.get('query', {}).get('pages', {})
                    
                    for page_data in pages.values():
                        if 'extract' in page_data:
                            return page_data['extract']
        except:
            pass
        
        return None
    
    def _extract_essential_data(self, content: str, fish_name: str) -> Dict:
        """Extract only the 6 essential fields for compatibility"""
        
        data = {}
        content_lower = content.lower()
        
        # 1. Water Type (CRITICAL)
        if re.search(r'\b(saltwater|marine|ocean|reef|sea)\b', content_lower):
            data['water_type'] = 'Saltwater'
        elif re.search(r'\b(freshwater|fresh water|river|lake)\b', content_lower):
            data['water_type'] = 'Freshwater'
        elif re.search(r'\bbrackish\b', content_lower):
            data['water_type'] = 'Brackish'
        
        # 2. Temperament (CRITICAL)
        if re.search(r'\b(aggressive|territorial|hostile|predatory|fighting)\b', content_lower):
            data['temperament'] = 'Aggressive'
        elif re.search(r'\b(semi.aggressive|moderately aggressive)\b', content_lower):
            data['temperament'] = 'Semi-aggressive'
        elif re.search(r'\b(peaceful|calm|docile|gentle|non.aggressive)\b', content_lower):
            data['temperament'] = 'Peaceful'
        
        # 3. Social Behavior (CRITICAL)
        if re.search(r'\b(school|schooling|shoal|shoaling)\b', content_lower):
            data['social_behavior'] = 'Schooling'
        elif re.search(r'\b(solitary|alone|single|individual)\b', content_lower):
            data['social_behavior'] = 'Solitary'
        elif re.search(r'\b(pair|pairs|couple)\b', content_lower):
            data['social_behavior'] = 'Pairs'
        elif re.search(r'\b(community|group|compatible)\b', content_lower):
            data['social_behavior'] = 'Community'
        
        # 4. Size (CRITICAL)
        size_patterns = [
            r'(?:grows?|reaches?|up to|maximum|length).*?(\d+(?:\.\d+)?)\s*(?:cm|centimeter|inch|")',
            r'(\d+(?:\.\d+)?)\s*(?:cm|centimeter|inch|")\s*(?:long|length)'
        ]
        
        for pattern in size_patterns:
            match = re.search(pattern, content_lower)
            if match:
                size = float(match.group(1))
                if 'inch' in match.group(0) or '"' in match.group(0):
                    size *= 2.54  # Convert to cm
                data['max_size_(cm)'] = size
                break
        
        # 5. Tank Size (IMPORTANT)
        tank_patterns = [
            r'(?:tank|aquarium).*?(\d+)\s*(?:gallon|litre|liter|l)\b',
            r'(\d+)\s*(?:gallon|litre|liter|l)\s*(?:tank|aquarium)'
        ]
        
        for pattern in tank_patterns:
            match = re.search(pattern, content_lower)
            if match:
                volume = float(match.group(1))
                if 'gallon' in match.group(0):
                    volume *= 3.78541  # Convert to liters
                data['minimum_tank_size_(l)'] = volume
                break
        
        # 6. Diet (IMPORTANT)
        if re.search(r'\b(herbivore|herbivorous|plant.eater|algae.eater|vegetation)\b', content_lower):
            data['diet'] = 'Herbivore'
        elif re.search(r'\b(carnivore|carnivorous|predator|meat.eater|fish.eater)\b', content_lower):
            data['diet'] = 'Carnivore'  
        elif re.search(r'\b(omnivore|omnivorous)\b', content_lower):
            data['diet'] = 'Omnivore'
        
        return data
    
    def _merge_and_fix_data(self, current_data: Dict, scraped_data: Dict, fish_name: str) -> Dict:
        """Merge current and scraped data, applying manual fixes for known issues"""
        
        # Start with current data
        fixed_data = current_data.copy()
        
        # Apply scraped data (prefer fresh data)
        for key, value in scraped_data.items():
            if value:  # Only update if scraped data has a value
                fixed_data[key] = value
        
        # Manual fixes for known problem fish
        fixed_data.update(self._apply_manual_fixes(fish_name, fixed_data))
        
        return fixed_data
    
    def _apply_manual_fixes(self, fish_name: str, data: Dict) -> Dict:
        """Apply manual fixes for fish with known incorrect data"""
        
        fixes = {}
        fish_lower = fish_name.lower()
        
        # Fix Blue Tang (and other tangs) - should NOT be solitary
        if 'tang' in fish_lower or 'surgeon' in fish_lower:
            fixes.update({
                'water_type': 'Saltwater',
                'social_behavior': 'Community',  # NOT solitary!
                'temperament': 'Peaceful'
            })
            
            if 'blue tang' in fish_lower:
                fixes.update({
                    'max_size_(cm)': 30.0,
                    'minimum_tank_size_(l)': 300.0,  # Large tank needed
                    'diet': 'Omnivore'
                })
        
        # Fix Clownfish
        if 'clown' in fish_lower and 'fish' in fish_lower:
            fixes.update({
                'water_type': 'Saltwater',
                'temperament': 'Peaceful',
                'social_behavior': 'Pairs',
                'max_size_(cm)': 10.0,
                'minimum_tank_size_(l)': 75.0,
                'diet': 'Omnivore'
            })
        
        # Fix common freshwater community fish
        if any(name in fish_lower for name in ['neon tetra', 'cardinal tetra', 'corydoras', 'cory']):
            fixes.update({
                'water_type': 'Freshwater',
                'temperament': 'Peaceful',
                'social_behavior': 'Schooling'
            })
        
        # Fix Angelfish
        if 'angelfish' in fish_lower and 'flame' not in fish_lower:
            fixes.update({
                'temperament': 'Semi-aggressive',  # Not peaceful!
                'social_behavior': 'Pairs'
            })
        
        # Ensure Betta stays solitary/aggressive
        if 'betta' in fish_lower:
            fixes.update({
                'water_type': 'Freshwater',
                'temperament': 'Aggressive',
                'social_behavior': 'Territorial'  # Keep as territorial
            })
        
        return fixes
    
    async def _update_database(self, fish_name: str, data: Dict):
        """Update database with fixed data"""
        try:
            # Remove empty values
            update_data = {k: v for k, v in data.items() if v is not None and v != ''}
            
            if update_data:
                self.supabase.table('fish_species').update(update_data).eq('common_name', fish_name).execute()
                logger.info(f"  ✅ Updated {fish_name} in database")
        except Exception as e:
            logger.error(f"  ❌ Failed to update {fish_name}: {str(e)}")

async def fix_problem_fish():
    """Fix the specific problem fish we identified"""
    
    # Focus on fish that have compatibility issues
    problem_fish = [
        "Blue Tang",
        "Yellow Tang", 
        "Clownfish",
        "Angelfish",
        "Foxface Rabbitfish",
        "Six Line Wrasse",
        "Coral Beauty"
    ]
    
    scraper = SimpleFishScraper()
    results = await scraper.scrape_and_fix_fish_data(problem_fish)
    
    print(f"Fixed data for {len(results)} fish:")
    for fish_name, data in results.items():
        print(f"\n{fish_name}:")
        essential_fields = ['water_type', 'temperament', 'social_behavior', 'max_size_(cm)', 'minimum_tank_size_l', 'diet']
        for field in essential_fields:
            if field in data:
                print(f"  {field}: {data[field]}")

if __name__ == "__main__":
    asyncio.run(fix_problem_fish())
