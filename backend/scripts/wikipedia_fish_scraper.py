#!/usr/bin/env python3
"""
Wikipedia Fish Data Scraper

This module scrapes basic fish data from Wikipedia, which has reliable
structured information for many fish species.
"""

import asyncio
import aiohttp
import json
import logging
import re
from typing import Dict, List, Optional, Any
from urllib.parse import quote
import sys
import os

# Add parent directory to path for app imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

logger = logging.getLogger(__name__)

class WikipediaFishScraper:
    """Scraper for Wikipedia fish data using MediaWiki API"""
    
    def __init__(self):
        self.base_url = "https://en.wikipedia.org/api/rest_v1"
        self.api_url = "https://en.wikipedia.org/w/api.php"
        
    async def scrape_fish_list(self, fish_names: List[str]) -> Dict[str, Dict[str, Any]]:
        """Scrape Wikipedia data for a list of fish"""
        results = {}
        
        async with aiohttp.ClientSession() as session:
            for fish_name in fish_names:
                logger.info(f"Scraping Wikipedia data for: {fish_name}")
                try:
                    fish_data = await self._scrape_single_fish(session, fish_name)
                    if fish_data:
                        results[fish_name] = fish_data
                        logger.info(f"  ✅ Found data for {fish_name}")
                    else:
                        logger.warning(f"  ❌ No data found for {fish_name}")
                except Exception as e:
                    logger.error(f"  ❌ Error scraping {fish_name}: {str(e)}")
                
                # Rate limiting
                await asyncio.sleep(1)
        
        return results
    
    async def _scrape_single_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        """Scrape data for a single fish from Wikipedia"""
        
        # First, search for the article
        page_title = await self._find_fish_page(session, fish_name)
        if not page_title:
            return None
        
        # Get the page content
        content = await self._get_page_content(session, page_title)
        if not content:
            return None
        
        # Extract fish data from the content
        return self._extract_fish_data(content, fish_name)
    
    async def _find_fish_page(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[str]:
        """Find the correct Wikipedia page for a fish"""
        
        # Try exact search first
        search_terms = [
            fish_name,
            f"{fish_name} fish",
            f"{fish_name} (fish)",
        ]
        
        for term in search_terms:
            params = {
                'action': 'query',
                'format': 'json',
                'list': 'search',
                'srsearch': term,
                'srnamespace': 0,
                'srlimit': 5
            }
            
            async with session.get(self.api_url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    search_results = data.get('query', {}).get('search', [])
                    
                    for result in search_results:
                        title = result['title']
                        snippet = result['snippet'].lower()
                        
                        # Check if this looks like a fish article
                        if any(keyword in snippet for keyword in ['fish', 'species', 'aquarium', 'marine', 'freshwater']):
                            return title
        
        return None
    
    async def _get_page_content(self, session: aiohttp.ClientSession, page_title: str) -> Optional[str]:
        """Get the content of a Wikipedia page"""
        
        params = {
            'action': 'query',
            'format': 'json',
            'titles': page_title,
            'prop': 'extracts',
            'exintro': True,
            'explaintext': True,
            'exsectionformat': 'plain'
        }
        
        async with session.get(self.api_url, params=params) as response:
            if response.status == 200:
                data = await response.json()
                pages = data.get('query', {}).get('pages', {})
                
                for page_id, page_data in pages.items():
                    if 'extract' in page_data:
                        return page_data['extract']
        
        return None
    
    def _extract_fish_data(self, content: str, fish_name: str) -> Dict[str, Any]:
        """Extract structured fish data from Wikipedia content"""
        data = {
            'common_name': fish_name,
            'source': 'wikipedia'
        }
        
        content_lower = content.lower()
        
        # Scientific name - look for binomial nomenclature
        scientific_match = re.search(r'\b([A-Z][a-z]+\s+[a-z]+)\b', content)
        if scientific_match:
            data['scientific_name'] = scientific_match.group(1)
        
        # Size information
        size_patterns = [
            r'(?:grows?|reaches?|attains?|up to|maximum).*?(\d+(?:\.\d+)?)\s*(?:cm|centimeters?|inches?|")',
            r'(?:length|size).*?(\d+(?:\.\d+)?)\s*(?:cm|centimeters?|inches?|")',
            r'(\d+(?:\.\d+)?)\s*(?:cm|centimeters?|inches?|")\s*(?:long|in length)'
        ]
        
        for pattern in size_patterns:
            match = re.search(pattern, content_lower)
            if match:
                size = float(match.group(1))
                if 'inch' in match.group(0) or '"' in match.group(0):
                    size *= 2.54  # Convert to cm
                data['max_size_cm'] = size
                break
        
        # Water type
        if re.search(r'\b(freshwater|fresh water)\b', content_lower):
            data['water_type'] = 'Freshwater'
        elif re.search(r'\b(saltwater|marine|ocean|reef)\b', content_lower):
            data['water_type'] = 'Saltwater'
        elif re.search(r'\bbrackish\b', content_lower):
            data['water_type'] = 'Brackish'
        
        # Temperament indicators
        if re.search(r'\b(peaceful|calm|docile|gentle|non-aggressive)\b', content_lower):
            data['temperament'] = 'Peaceful'
        elif re.search(r'\b(aggressive|territorial|hostile|predatory)\b', content_lower):
            data['temperament'] = 'Aggressive'
        elif re.search(r'\b(semi-aggressive|moderately aggressive)\b', content_lower):
            data['temperament'] = 'Semi-aggressive'
        
        # Social behavior
        if re.search(r'\b(school|schooling|shoal|shoaling|group|groups)\b', content_lower):
            data['social_behavior'] = 'Schooling'
        elif re.search(r'\b(solitary|alone|single|individual)\b', content_lower):
            data['social_behavior'] = 'Solitary'
        elif re.search(r'\b(pair|pairs|couple|couples)\b', content_lower):
            data['social_behavior'] = 'Pairs'
        elif re.search(r'\b(community|compatible|peaceful)\b', content_lower):
            data['social_behavior'] = 'Community'
        
        # Diet
        if re.search(r'\b(herbivore|herbivorous|plant|algae|vegetation)\b', content_lower):
            data['diet'] = 'Herbivore'
        elif re.search(r'\b(carnivore|carnivorous|predator|meat|fish)\b', content_lower):
            data['diet'] = 'Carnivore'
        elif re.search(r'\b(omnivore|omnivorous)\b', content_lower):
            data['diet'] = 'Omnivore'
        
        # Tank/aquarium information
        tank_match = re.search(r'aquarium.*?(\d+)\s*(?:gallon|litre|liter|l)\b', content_lower)
        if tank_match:
            volume = float(tank_match.group(1))
            if 'gallon' in tank_match.group(0):
                volume *= 3.78541  # Convert to liters
            data['min_tank_size_l'] = volume
        
        # Origin/native region
        origin_patterns = [
            r'native to ([^.]+)',
            r'found in ([^.]+)',
            r'endemic to ([^.]+)',
            r'from ([^.]+)'
        ]
        
        for pattern in origin_patterns:
            match = re.search(pattern, content_lower)
            if match:
                origin = match.group(1).strip()
                if len(origin) < 50:  # Reasonable length
                    data['origin'] = origin.title()
                break
        
        return data

async def test_wikipedia_scraper():
    """Test the Wikipedia scraper with sample fish"""
    
    test_fish = [
        "Blue Tang", 
        "Clownfish", 
        "Neon Tetra", 
        "Angelfish",
        "Betta",
        "Yellow Tang",
        "Cardinal Tetra"
    ]
    
    scraper = WikipediaFishScraper()
    results = await scraper.scrape_fish_list(test_fish)
    
    # Save results
    with open('wikipedia_fish_data.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"Scraped data for {len(results)} fish from Wikipedia")
    print("Results saved to wikipedia_fish_data.json")
    
    # Show sample results
    for fish_name, data in results.items():
        print(f"\n{fish_name}:")
        for key, value in data.items():
            print(f"  {key}: {value}")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(test_wikipedia_scraper())
