#!/usr/bin/env python3
"""
Fast BM25 Search Service for Fish Species
Uses pre-computed indexes and caching for ultra-fast search
"""

import json
import math
import re
from typing import List, Dict, Any, Optional
from collections import defaultdict
import asyncio
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class BM25SearchService:
    def __init__(self):
        self.fish_data: List[Dict[str, Any]] = []
        self.inverted_index: Dict[str, Dict[int, int]] = defaultdict(dict)  # term -> {doc_id: freq}
        self.doc_lengths: List[int] = []
        self.avg_doc_length: float = 0.0
        self.doc_count: int = 0
        
        # BM25 parameters
        self.k1 = 1.2
        self.b = 0.75
        
        # Field weights
        self.field_weights = {
            'common_name': 3.0,
            'scientific_name': 2.5,
            'description': 2.0,
            'temperament': 1.8,
            'water_type': 1.5,
            'habitat_type': 1.5,
            'diet': 1.3,
            'social_behavior': 1.3,
            'care_level': 1.2,
            'tank_level': 1.0,
            'ph_range': 0.8,
            'temperature_range': 0.8,
            'feeding_frequency': 0.7,
            'preferred_food': 0.7,
            'feeding_notes': 0.6,
            'overfeeding_risks': 0.6,
            'lifespan': 0.5,
            'max_size_(cm)': 0.4,
            'minimum_tank_size_(l)': 0.4,
        }
        
        # Cache
        self.cache: Dict[str, List[Dict[str, Any]]] = {}
        self.cache_timestamp: Optional[datetime] = None
        self.cache_duration = timedelta(minutes=30)
        
    def preprocess_text(self, text: str) -> List[str]:
        """Preprocess text for indexing and searching"""
        if not text:
            return []
        
        # Convert to lowercase and remove punctuation
        text = re.sub(r'[^\w\s]', ' ', text.lower())
        # Split into words and remove empty strings
        words = [word.strip() for word in text.split() if word.strip()]
        return words
    
    def build_index(self, fish_data: List[Dict[str, Any]]):
        """Build inverted index from fish data"""
        logger.info(f"Building BM25 index for {len(fish_data)} fish...")
        
        self.fish_data = fish_data
        self.doc_count = len(fish_data)
        self.inverted_index.clear()
        self.doc_lengths = []
        
        total_length = 0
        
        for doc_id, fish in enumerate(fish_data):
            doc_length = 0
            
            # Process each searchable field
            for field_name, weight in self.field_weights.items():
                if field_name in fish and fish[field_name]:
                    field_text = str(fish[field_name])
                    words = self.preprocess_text(field_text)
                    
                    # Add words to inverted index with field weight
                    for word in words:
                        if word not in self.inverted_index:
                            self.inverted_index[word] = {}
                        
                        if doc_id not in self.inverted_index[word]:
                            self.inverted_index[word][doc_id] = 0
                        
                        # Weight the term frequency by field importance
                        self.inverted_index[word][doc_id] += weight
                        doc_length += weight
            
            self.doc_lengths.append(doc_length)
            total_length += doc_length
        
        self.avg_doc_length = total_length / self.doc_count if self.doc_count > 0 else 0
        logger.info(f"Index built: {len(self.inverted_index)} unique terms, avg doc length: {self.avg_doc_length:.2f}")
    
    def calculate_bm25_score(self, term: str, doc_id: int) -> float:
        """Calculate BM25 score for a term in a document"""
        if term not in self.inverted_index or doc_id not in self.inverted_index[term]:
            return 0.0
        
        tf = self.inverted_index[term][doc_id]
        doc_length = self.doc_lengths[doc_id]
        
        # Calculate IDF (simplified - in production, calculate from corpus)
        df = len(self.inverted_index[term])
        idf = math.log((self.doc_count - df + 0.5) / (df + 0.5))
        
        # BM25 formula
        numerator = tf * (self.k1 + 1)
        denominator = tf + self.k1 * (1 - self.b + self.b * (doc_length / self.avg_doc_length))
        
        return idf * (numerator / denominator)
    
    def search(self, query: str, limit: int = 100, min_score: float = 0.01) -> List[Dict[str, Any]]:
        """Search for fish using BM25 algorithm"""
        if not query or not self.fish_data:
            return []
        
        # Check cache first
        cache_key = f"{query.lower()}_{limit}_{min_score}"
        if (self.cache_timestamp and 
            datetime.now() - self.cache_timestamp < self.cache_duration and 
            cache_key in self.cache):
            logger.info(f"Returning cached results for: {query}")
            return self.cache[cache_key]
        
        # Preprocess query
        query_terms = self.preprocess_text(query)
        if not query_terms:
            return []
        
        logger.info(f"Searching for: {query} (terms: {query_terms})")
        
        # Calculate scores for all documents
        doc_scores = defaultdict(float)
        matched_fields = defaultdict(set)
        
        for term in query_terms:
            if term in self.inverted_index:
                for doc_id in self.inverted_index[term]:
                    score = self.calculate_bm25_score(term, doc_id)
                    doc_scores[doc_id] += score
                    
                    # Track which fields matched
                    fish = self.fish_data[doc_id]
                    for field_name in self.field_weights.keys():
                        if (field_name in fish and fish[field_name] and 
                            term in self.preprocess_text(str(fish[field_name]))):
                            matched_fields[doc_id].add(field_name)
        
        # Sort by score and filter
        results = []
        for doc_id, score in doc_scores.items():
            if score >= min_score:
                fish_data = self.fish_data[doc_id].copy()
                fish_data['search_score'] = score
                fish_data['matched_fields'] = list(matched_fields[doc_id])
                results.append(fish_data)
        
        # Sort by score (descending) and limit results
        results.sort(key=lambda x: x['search_score'], reverse=True)
        results = results[:limit]
        
        logger.info(f"Found {len(results)} results for: {query}")
        
        # Cache results
        self.cache[cache_key] = results
        self.cache_timestamp = datetime.now()
        
        return results
    
    def get_autocomplete_suggestions(self, query: str, limit: int = 8) -> List[str]:
        """Get autocomplete suggestions"""
        if not query or not self.fish_data:
            return []
        
        query_lower = query.lower()
        suggestions = set()
        
        for fish in self.fish_data:
            # Add common names
            if 'common_name' in fish and fish['common_name']:
                name = str(fish['common_name'])
                if query_lower in name.lower():
                    suggestions.add(name)
            
            # Add scientific names
            if 'scientific_name' in fish and fish['scientific_name']:
                name = str(fish['scientific_name'])
                if query_lower in name.lower():
                    suggestions.add(name)
            
            # Add water types
            if 'water_type' in fish and fish['water_type']:
                water_type = str(fish['water_type'])
                if query_lower in water_type.lower():
                    suggestions.add(water_type)
            
            # Add temperaments
            if 'temperament' in fish and fish['temperament']:
                temperament = str(fish['temperament'])
                if query_lower in temperament.lower():
                    suggestions.add(temperament)
            
            # Add habitat types
            if 'habitat_type' in fish and fish['habitat_type']:
                habitat = str(fish['habitat_type'])
                if query_lower in habitat.lower():
                    suggestions.add(habitat)
        
        return list(suggestions)[:limit]

# Global instance
bm25_service = BM25SearchService()

async def initialize_bm25_service(fish_data: List[Dict[str, Any]]):
    """Initialize the BM25 service with fish data"""
    bm25_service.build_index(fish_data)
    logger.info("BM25 service initialized successfully")

async def search_fish(query: str, limit: int = 100, min_score: float = 0.01) -> List[Dict[str, Any]]:
    """Search for fish using BM25"""
    return bm25_service.search(query, limit, min_score)

async def get_autocomplete_suggestions(query: str, limit: int = 8) -> List[str]:
    """Get autocomplete suggestions"""
    return bm25_service.get_autocomplete_suggestions(query, limit)
