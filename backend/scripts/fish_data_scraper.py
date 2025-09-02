#!/usr/bin/env python3
"""
Advanced Fish Data Scraper for AquaSync

This module scrapes fish data from multiple reliable sources to build
a comprehensive and accurate fish database for compatibility analysis.

Sources:
- FishBase.org (Scientific data)
- LiveAquaria.com (Aquarium trade data)
- SeriouslyFish.com (Hobbyist data)
- AqAdvisor.com (Compatibility data)
"""

import asyncio
import aiohttp
import requests
from bs4 import BeautifulSoup
import json
import time
import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import re
import os
import sys
from urllib.parse import urljoin, quote
import hashlib

# Add parent directory to path for app imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.supabase_config import get_supabase_client

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('fish_scraper.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class FishData:
    """Standardized fish data structure"""
    common_name: str
    scientific_name: str = ""
    family: str = ""
    water_type: str = ""  # Freshwater, Saltwater, Brackish
    temperament: str = ""  # Peaceful, Semi-aggressive, Aggressive
    social_behavior: str = ""  # Schooling, Pairs, Solitary, Community
    max_size_cm: float = 0.0
    min_tank_size_l: float = 0.0
    tank_level: str = ""  # Top, Mid, Bottom, All
    diet: str = ""  # Carnivore, Herbivore, Omnivore
    care_level: str = ""  # Beginner, Intermediate, Expert
    ph_range: str = ""  # e.g., "6.5-7.5"
    temperature_range_c: str = ""  # e.g., "22-26"
    lifespan_years: str = ""
    breeding: str = ""
    origin: str = ""
    reef_safe: bool = None  # For saltwater fish
    sources: List[str] = None  # Track which sources provided data
    confidence_score: float = 0.0  # Based on source agreement
    last_updated: str = ""
    
    def __post_init__(self):
        if self.sources is None:
            self.sources = []
        if not self.last_updated:
            self.last_updated = datetime.now(timezone.utc).isoformat()

class FishDataScraper:
    """Main scraper coordinator class"""
    
    def __init__(self):
        self.session = None
        self.scraped_data: Dict[str, FishData] = {}
        self.source_scrapers = {
            'fishbase': FishBaseScraper(),
            'liveaquaria': LiveAquariaScraper(),
            'seriouslyfish': SeriouslyFishScraper(),
            'aqadvisor': AqAdvisorScraper()
        }
        self.supabase = get_supabase_client()
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30),
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def scrape_fish_list(self, fish_names: List[str]) -> Dict[str, FishData]:
        """Scrape data for a list of fish from multiple sources"""
        logger.info(f"Starting to scrape data for {len(fish_names)} fish")
        
        for fish_name in fish_names:
            logger.info(f"Scraping data for: {fish_name}")
            fish_data = FishData(common_name=fish_name)
            
            # Scrape from each source
            for source_name, scraper in self.source_scrapers.items():
                try:
                    logger.info(f"  Scraping from {source_name}...")
                    source_data = await scraper.scrape_fish(self.session, fish_name)
                    if source_data:
                        fish_data = self._merge_fish_data(fish_data, source_data, source_name)
                        logger.info(f"  ✅ {source_name}: Got data")
                    else:
                        logger.warning(f"  ❌ {source_name}: No data found")
                except Exception as e:
                    logger.error(f"  ❌ {source_name}: Error - {str(e)}")
                
                # Rate limiting between sources
                await asyncio.sleep(1)
            
            # Calculate confidence score based on source agreement
            fish_data.confidence_score = self._calculate_confidence(fish_data)
            self.scraped_data[fish_name] = fish_data
            
            # Rate limiting between fish
            await asyncio.sleep(2)
        
        return self.scraped_data
    
    def _merge_fish_data(self, base_data: FishData, source_data: Dict[str, Any], source_name: str) -> FishData:
        """Merge data from a source into the base fish data"""
        base_data.sources.append(source_name)
        
        # Merge non-empty fields, preferring more specific/reliable sources
        source_priority = {'fishbase': 4, 'seriouslyfish': 3, 'liveaquaria': 2, 'aqadvisor': 1}
        current_priority = len(base_data.sources)
        
        for field, value in source_data.items():
            if value and hasattr(base_data, field):
                current_value = getattr(base_data, field)
                if not current_value or source_priority.get(source_name, 0) > current_priority:
                    setattr(base_data, field, value)
        
        return base_data
    
    def _calculate_confidence(self, fish_data: FishData) -> float:
        """Calculate confidence score based on data completeness and source agreement"""
        # Base score from number of sources
        source_score = min(len(fish_data.sources) / 4.0, 1.0) * 0.4
        
        # Completeness score
        important_fields = [
            'scientific_name', 'water_type', 'temperament', 'social_behavior',
            'max_size_cm', 'min_tank_size_l', 'diet', 'ph_range', 'temperature_range_c'
        ]
        filled_fields = sum(1 for field in important_fields if getattr(fish_data, field))
        completeness_score = (filled_fields / len(important_fields)) * 0.6
        
        return source_score + completeness_score
    
    async def save_to_database(self, overwrite_existing: bool = False):
        """Save scraped data to Supabase database"""
        logger.info(f"Saving {len(self.scraped_data)} fish to database...")
        
        for fish_name, fish_data in self.scraped_data.items():
            try:
                # Convert to database format
                db_data = {
                    'common_name': fish_data.common_name,
                    'scientific_name': fish_data.scientific_name,
                    'family': fish_data.family,
                    'water_type': fish_data.water_type,
                    'temperament': fish_data.temperament,
                    'social_behavior': fish_data.social_behavior,
                    'max_size_(cm)': fish_data.max_size_cm,
                    'minimum_tank_size_l': fish_data.min_tank_size_l,
                    'tank_level': fish_data.tank_level,
                    'diet': fish_data.diet,
                    'care_level': fish_data.care_level,
                    'ph_range': fish_data.ph_range,
                    'temperature_range_c': fish_data.temperature_range_c,
                    'lifespan': fish_data.lifespan_years,
                    'breeding': fish_data.breeding,
                    'origin': fish_data.origin,
                    'reef_safe': fish_data.reef_safe,
                    'data_sources': fish_data.sources,
                    'confidence_score': fish_data.confidence_score,
                    'last_updated': fish_data.last_updated
                }
                
                # Remove None values
                db_data = {k: v for k, v in db_data.items() if v is not None}
                
                if overwrite_existing:
                    # Upsert (update or insert)
                    response = self.supabase.table('fish_species').upsert(db_data).execute()
                else:
                    # Insert only if doesn't exist
                    existing = self.supabase.table('fish_species').select('common_name').eq('common_name', fish_name).execute()
                    if not existing.data:
                        response = self.supabase.table('fish_species').insert(db_data).execute()
                        logger.info(f"  ✅ Inserted: {fish_name}")
                    else:
                        logger.info(f"  ⏭️  Skipped (exists): {fish_name}")
                        
            except Exception as e:
                logger.error(f"  ❌ Failed to save {fish_name}: {str(e)}")

class BaseScraper:
    """Base class for individual source scrapers"""
    
    def __init__(self, name: str, base_url: str):
        self.name = name
        self.base_url = base_url
        self.cache = {}
    
    async def scrape_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        """Override this method in subclasses"""
        raise NotImplementedError
    
    def _normalize_fish_name(self, name: str) -> str:
        """Normalize fish name for searching"""
        return re.sub(r'[^\w\s]', '', name.lower().strip())
    
    def _parse_size(self, size_str: str) -> float:
        """Parse size string to cm"""
        if not size_str:
            return 0.0
        
        # Extract numbers and handle common units
        match = re.search(r'(\d+(?:\.\d+)?)', size_str.lower())
        if match:
            size = float(match.group(1))
            if 'inch' in size_str or '"' in size_str:
                size *= 2.54  # Convert inches to cm
            return size
        return 0.0
    
    def _parse_volume(self, volume_str: str) -> float:
        """Parse tank volume to liters"""
        if not volume_str:
            return 0.0
        
        match = re.search(r'(\d+(?:\.\d+)?)', volume_str.lower())
        if match:
            volume = float(match.group(1))
            if 'gallon' in volume_str or 'gal' in volume_str:
                volume *= 3.78541  # Convert gallons to liters
            return volume
        return 0.0

class FishBaseScraper(BaseScraper):
    """Scraper for FishBase.org - Scientific fish database"""
    
    def __init__(self):
        super().__init__("FishBase", "https://www.fishbase.se")
    
    async def scrape_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        # FishBase scraping implementation
        search_url = f"{self.base_url}/search.php"
        
        # Implementation will be added based on FishBase's structure
        # This is a placeholder for the actual scraping logic
        return None

class LiveAquariaScraper(BaseScraper):
    """Scraper for LiveAquaria.com - Aquarium trade data"""
    
    def __init__(self):
        super().__init__("LiveAquaria", "https://www.liveaquaria.com")
    
    async def scrape_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        # LiveAquaria scraping implementation
        # This will be implemented based on their site structure
        return None

class SeriouslyFishScraper(BaseScraper):
    """Scraper for SeriouslyFish.com - Comprehensive fish profiles"""
    
    def __init__(self):
        super().__init__("SeriouslyFish", "https://www.seriouslyfish.com")
    
    async def scrape_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        try:
            # Search for the fish
            search_url = f"{self.base_url}/species"
            normalized_name = fish_name.lower().replace(' ', '-')
            
            # Try direct URL first (common pattern)
            fish_url = f"{search_url}/{normalized_name}/"
            
            async with session.get(fish_url) as response:
                if response.status != 200:
                    # Try alternative URL patterns
                    alternatives = [
                        f"{search_url}/{normalized_name.replace('-', '_')}/",
                        f"{search_url}/{fish_name.lower().replace(' ', '')}/",
                    ]
                    
                    found = False
                    for alt_url in alternatives:
                        try:
                            async with session.get(alt_url) as alt_response:
                                if alt_response.status == 200:
                                    response = alt_response
                                    found = True
                                    break
                        except:
                            continue
                    
                    if not found:
                        return None
                
                html = await response.text()
                soup = BeautifulSoup(html, 'html.parser')
                
                # Extract fish data from SeriouslyFish page structure
                data = {}
                
                # Common name (from title or header)
                title = soup.find('h1') or soup.find('title')
                if title:
                    data['common_name'] = title.get_text().strip()
                
                # Look for data in various possible containers
                info_sections = soup.find_all(['div', 'section', 'article'], class_=re.compile(r'(info|detail|profile|species)', re.I))
                
                for section in info_sections:
                    text = section.get_text().lower()
                    
                    # Scientific name
                    scientific_match = re.search(r'scientific[:\s]+([a-z]+\s+[a-z]+)', text)
                    if scientific_match and not data.get('scientific_name'):
                        data['scientific_name'] = scientific_match.group(1).title()
                    
                    # Size
                    size_match = re.search(r'(?:size|length)[:\s]+(\d+(?:\.\d+)?)\s*(?:cm|inch|")', text)
                    if size_match and not data.get('max_size_cm'):
                        size = float(size_match.group(1))
                        if 'inch' in text or '"' in text:
                            size *= 2.54
                        data['max_size_cm'] = size
                    
                    # Tank size
                    tank_match = re.search(r'(?:tank|aquarium)[:\s]+(\d+)\s*(?:l|litre|liter|gallon)', text)
                    if tank_match and not data.get('min_tank_size_l'):
                        volume = float(tank_match.group(1))
                        if 'gallon' in text:
                            volume *= 3.78541
                        data['min_tank_size_l'] = volume
                    
                    # Temperament
                    if re.search(r'\b(peaceful|calm|docile)\b', text) and not data.get('temperament'):
                        data['temperament'] = 'Peaceful'
                    elif re.search(r'\b(aggressive|territorial|hostile)\b', text) and not data.get('temperament'):
                        data['temperament'] = 'Aggressive'
                    elif re.search(r'\b(semi.aggressive|moderately aggressive)\b', text) and not data.get('temperament'):
                        data['temperament'] = 'Semi-aggressive'
                    
                    # Social behavior
                    if re.search(r'\b(schooling|shoaling|group)\b', text) and not data.get('social_behavior'):
                        data['social_behavior'] = 'Schooling'
                    elif re.search(r'\b(solitary|alone|single)\b', text) and not data.get('social_behavior'):
                        data['social_behavior'] = 'Solitary'
                    elif re.search(r'\b(pairs|couple)\b', text) and not data.get('social_behavior'):
                        data['social_behavior'] = 'Pairs'
                    elif re.search(r'\b(community|compatible)\b', text) and not data.get('social_behavior'):
                        data['social_behavior'] = 'Community'
                    
                    # Water type
                    if re.search(r'\b(freshwater|fresh water)\b', text) and not data.get('water_type'):
                        data['water_type'] = 'Freshwater'
                    elif re.search(r'\b(saltwater|marine|reef)\b', text) and not data.get('water_type'):
                        data['water_type'] = 'Saltwater'
                    elif re.search(r'\b(brackish)\b', text) and not data.get('water_type'):
                        data['water_type'] = 'Brackish'
                    
                    # pH range
                    ph_match = re.search(r'ph[:\s]+(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)', text)
                    if ph_match and not data.get('ph_range'):
                        data['ph_range'] = f"{ph_match.group(1)}-{ph_match.group(2)}"
                    
                    # Temperature
                    temp_match = re.search(r'temperature[:\s]+(\d+)\s*[-–]\s*(\d+)\s*[°]?c', text)
                    if temp_match and not data.get('temperature_range_c'):
                        data['temperature_range_c'] = f"{temp_match.group(1)}-{temp_match.group(2)}"
                
                return data if data else None
                
        except Exception as e:
            logger.error(f"Error scraping SeriouslyFish for {fish_name}: {str(e)}")
            return None

class AqAdvisorScraper(BaseScraper):
    """Scraper for AqAdvisor.com - Tank compatibility data"""
    
    def __init__(self):
        super().__init__("AqAdvisor", "http://www.aqadvisor.com")
    
    async def scrape_fish(self, session: aiohttp.ClientSession, fish_name: str) -> Optional[Dict[str, Any]]:
        # AqAdvisor scraping implementation
        # This will be implemented based on their site structure
        return None

async def main():
    """Main function to run the scraper"""
    # Test with a small set of fish first
    test_fish = [
        "Blue Tang", "Clownfish", "Yellow Tang", "Neon Tetra", 
        "Cardinal Tetra", "Angelfish", "Betta", "Corydoras Catfish"
    ]
    
    async with FishDataScraper() as scraper:
        scraped_data = await scraper.scrape_fish_list(test_fish)
        
        # Save results to JSON for review
        results = {}
        for fish_name, fish_data in scraped_data.items():
            results[fish_name] = asdict(fish_data)
        
        with open('scraped_fish_data.json', 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        logger.info(f"Scraped data saved to scraped_fish_data.json")
        logger.info(f"Average confidence score: {sum(fd.confidence_score for fd in scraped_data.values()) / len(scraped_data):.2f}")

if __name__ == "__main__":
    asyncio.run(main())
