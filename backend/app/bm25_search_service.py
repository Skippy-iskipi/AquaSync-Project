#!/usr/bin/env python3
"""
Improved BM25 Search Service for Fish Species
Context-aware matching that prioritizes semantic meaning over substring matches
"""

import json
import math
import re
from typing import List, Dict, Any, Optional, Set, Tuple
from collections import defaultdict
import asyncio
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class BM25SearchService:
    def __init__(self):
        self.fish_data: List[Dict[str, Any]] = []
        self.inverted_index: Dict[str, Dict[int, int]] = defaultdict(dict)
        self.doc_lengths: List[int] = []
        self.avg_doc_length: float = 0.0
        self.doc_count: int = 0
        self._last_expanded_terms: set = set()
        
        # BM25 parameters
        self.k1 = 1.5
        self.b = 0.75
        
        # Field weights - rebalanced to prevent name substring dominance
        self.field_weights = {
            'temperament': 10.0,  # Highest - most important attribute
            'water_type': 6.0,
            'care_level': 5.0,
            'diet': 5.0,
            'social_behavior': 5.0,
            'habitat_type': 4.0,
            'common_name': 3.0,  # Reduced - prevent substring dominance
            'tank_level': 3.0,
            'scientific_name': 2.5,
            'ph_range': 2.0,
            'temperature_range': 2.0,
            'preferred_food': 2.0,
            'feeding_frequency': 1.5,
            'description': 1.0,  # Lowest weight
            'feeding_notes': 1.0,
            'overfeeding_risks': 0.8,
            'lifespan': 1.0,
            'max_size_(cm)': 0.8,
            'minimum_tank_size_(l)': 0.8,
        }
        
        # Attribute keywords that should ONLY match in their respective fields
        self.attribute_keywords = {
            'peaceful', 'aggressive', 'semi-aggressive', 'calm', 'gentle', 'docile', 
            'friendly', 'hostile', 'territorial', 'violent', 'combative',
            'freshwater', 'saltwater', 'brackish', 'marine',
            'easy', 'moderate', 'difficult', 'beginner', 'intermediate', 'advanced',
            'omnivore', 'carnivore', 'herbivore', 'omnivorous', 'carnivorous', 'herbivorous',
            'community', 'solitary', 'schooling', 'shoaling', 'social',
            'tropical', 'coldwater', 'temperate'
        }
        
        # Enhanced synonym mappings
        self.synonyms = {
            'peaceful': ['calm', 'gentle', 'docile', 'friendly', 'non-aggressive'],
            'aggressive': ['hostile', 'territorial', 'violent', 'combative'],
            'semi-aggressive': ['semi aggressive', 'moderately aggressive', 'somewhat aggressive'],
            'freshwater': ['fresh water'],
            'saltwater': ['salt water', 'marine', 'ocean'],
            'brackish': ['brackish water'],
            'tropical': ['warm water'],
            'coldwater': ['cold water'],
            'community': ['social', 'group', 'schooling', 'shoaling'],
            'solitary': ['alone', 'individual', 'independent', 'single'],
            'easy': ['beginner', 'simple', 'basic', 'hardy'],
            'moderate': ['intermediate', 'medium', 'average'],
            'difficult': ['hard', 'advanced', 'expert', 'challenging'],
            'omnivore': ['omnivorous'],
            'carnivore': ['carnivorous', 'predator', 'meat eater'],
            'herbivore': ['herbivorous', 'plant eater', 'vegetarian'],
            'surface': ['top', 'upper'],
            'bottom': ['substrate', 'ground', 'floor', 'lower'],
        }
        
        # Build reverse synonym map
        self.reverse_synonyms = {}
        for main_term, synonyms in self.synonyms.items():
            self.reverse_synonyms[main_term] = main_term
            for syn in synonyms:
                self.reverse_synonyms[syn] = main_term
        
        # Cache
        self.cache: Dict[str, List[Dict[str, Any]]] = {}
        self.cache_timestamp: Optional[datetime] = None
        self.cache_duration = timedelta(minutes=30)
        
    def normalize_term(self, text: str) -> str:
        """Normalize a term by removing punctuation and extra spaces"""
        return re.sub(r'[^\w\s]', ' ', text.lower()).strip()
    
    def is_attribute_keyword(self, term: str) -> bool:
        """Check if term is a known attribute keyword"""
        normalized = self.normalize_term(term)
        # Check exact match
        if normalized in self.attribute_keywords:
            return True
        # Check if it's a synonym
        if normalized in self.reverse_synonyms:
            return True
        return False
    
    def preprocess_text(self, text: str, field_name: str = '', create_ngrams: bool = True) -> List[str]:
        """
        Preprocess text with field-aware tokenization
        Creates prefix tokens for better partial matching
        """
        if not text:
            return []
        
        normalized = self.normalize_term(text)
        words = [w for w in normalized.split() if len(w) >= 2]
        
        processed = set()
        
        # For common_name field - create prefix tokens but avoid aggressive short matches
        if field_name == 'common_name':
            # Add full name
            if len(words) > 1:
                processed.add(normalized)
            
            # Add individual words with prefix matching
            for word in words:
                if len(word) >= 3:
                    processed.add(word)
                    # Create prefixes for words 4+ chars to enable autocomplete
                    # e.g., "betta" -> "bet", "bett", "betta"
                    if len(word) >= 4:
                        for i in range(3, len(word)):
                            processed.add(word[:i])
        
        # For attribute fields - exact terms plus prefixes for longer words
        elif field_name in ['temperament', 'water_type', 'care_level', 'diet', 'social_behavior']:
            for word in words:
                processed.add(word)
                # Add prefixes for attribute values (e.g., "aggressive" -> "agg", "aggr", etc.)
                if len(word) >= 5:
                    for i in range(3, len(word)):
                        processed.add(word[:i])
            if len(words) > 1:
                processed.add(normalized)
        
        # For other fields, add words and create n-grams
        else:
            for word in words:
                processed.add(word)
                # Add prefixes for longer words
                if len(word) >= 4:
                    for i in range(3, len(word)):
                        processed.add(word[:i])
            
            # Create bigrams
            if create_ngrams and len(words) > 1:
                for i in range(len(words) - 1):
                    processed.add(f"{words[i]} {words[i+1]}")
        
        return list(processed)
    
    def expand_query_terms(self, query: str) -> Tuple[Set[str], bool]:
        """
        Expand query with context awareness
        Returns: (expanded_terms, is_attribute_search)
        """
        normalized_query = self.normalize_term(query)
        words = normalized_query.split()
        expanded = set()
        is_attribute_search = False
        
        # Check if this is an attribute keyword search
        for word in words:
            if self.is_attribute_keyword(word):
                is_attribute_search = True
                break
            # Check for partial attribute keyword match (4+ chars)
            if len(word) >= 4:
                for attr in self.attribute_keywords:
                    if attr.startswith(word):
                        is_attribute_search = True
                        break
        
        # Add original query
        if len(words) > 1:
            expanded.add(normalized_query)
        
        # Process each word
        for word in words:
            if len(word) < 2:
                continue
            
            # Add the word itself
            expanded.add(word)
            
            # Exact synonym match
            if word in self.reverse_synonyms:
                main_term = self.reverse_synonyms[word]
                expanded.add(main_term)
                if main_term in self.synonyms:
                    expanded.update(self.synonyms[main_term])
                is_attribute_search = True
            
            # Prefix matching for attribute keywords (4+ chars)
            if len(word) >= 4:
                for main_term, synonyms in self.synonyms.items():
                    # Check main term
                    if main_term.startswith(word):
                        expanded.add(main_term)
                        expanded.update(synonyms)
                        is_attribute_search = True
                        continue
                    
                    # Check synonyms
                    for syn in synonyms:
                        if syn.startswith(word):
                            expanded.add(main_term)
                            expanded.update(synonyms)
                            is_attribute_search = True
                            break
            
            # Add prefixes for partial matching (3+ chars)
            # This allows "bet" to match indexed "bet" prefix from "betta"
            if len(word) >= 3:
                for i in range(3, len(word) + 1):
                    expanded.add(word[:i])
        
        return expanded, is_attribute_search
    
    def build_index(self, fish_data: List[Dict[str, Any]]):
        """Build inverted index with field-aware tokenization"""
        logger.info(f"Building BM25 index for {len(fish_data)} fish...")
        
        self.fish_data = fish_data
        self.doc_count = len(fish_data)
        self.inverted_index.clear()
        self.doc_lengths = []
        
        total_length = 0
        
        for doc_id, fish in enumerate(fish_data):
            doc_length = 0
            
            # Debug first few documents
            if doc_id < 3:
                logger.info(f"Indexing fish #{doc_id}: {fish.get('common_name', 'Unknown')}")
                logger.info(f"  Temperament: {fish.get('temperament', 'N/A')}")
            
            # Process each searchable field
            for field_name, weight in self.field_weights.items():
                if field_name not in fish or not fish[field_name]:
                    continue
                
                field_text = str(fish[field_name])
                tokens = self.preprocess_text(field_text, field_name=field_name, create_ngrams=True)
                
                if doc_id < 3 and field_name in ['temperament', 'common_name']:
                    logger.info(f"  {field_name}: {field_text} -> {tokens}")
                
                # Add to inverted index
                for token in tokens:
                    if token not in self.inverted_index:
                        self.inverted_index[token] = {}
                    
                    if doc_id not in self.inverted_index[token]:
                        self.inverted_index[token][doc_id] = 0
                    
                    self.inverted_index[token][doc_id] += weight
                    doc_length += weight
            
            self.doc_lengths.append(doc_length)
            total_length += doc_length
        
        self.avg_doc_length = total_length / self.doc_count if self.doc_count > 0 else 0
        
        # Debug index stats
        sample_terms = ['peaceful', 'aggressive', 'pea', 'bet', 'bett', 'betta', 'freshwater']
        for term in sample_terms:
            if term in self.inverted_index:
                count = len(self.inverted_index[term])
                logger.info(f"Index: '{term}' found in {count} documents")
                if count > 0 and count <= 3:
                    # Show which docs for debugging
                    sample_docs = list(self.inverted_index[term].keys())[:3]
                    sample_names = [self.fish_data[i].get('common_name', 'Unknown') for i in sample_docs]
                    logger.info(f"  Sample docs: {sample_names}")
            else:
                logger.info(f"Index: '{term}' NOT FOUND")
        
        logger.info(f"Index built: {len(self.inverted_index)} unique terms, "
                   f"avg doc length: {self.avg_doc_length:.2f}")
    
    def calculate_bm25_score(self, term: str, doc_id: int, is_attribute_search: bool = False) -> float:
        """Calculate BM25 score with attribute boost"""
        if term not in self.inverted_index or doc_id not in self.inverted_index[term]:
            return 0.0
        
        tf = self.inverted_index[term][doc_id]
        doc_length = self.doc_lengths[doc_id]
        
        # IDF calculation with smoothing
        df = len(self.inverted_index[term])
        idf = math.log((self.doc_count - df + 0.5) / (df + 0.5) + 1.0)
        
        # BM25 formula
        numerator = tf * (self.k1 + 1)
        denominator = tf + self.k1 * (1 - self.b + self.b * (doc_length / self.avg_doc_length))
        
        score = idf * (numerator / denominator)
        
        # Boost score if this is an attribute search and term is an attribute keyword
        if is_attribute_search and self.is_attribute_keyword(term):
            score *= 2.0  # Significant boost for exact attribute matches
        
        return score
    
    def search(self, query: str, limit: int = 100, min_score: float = 0.01) -> List[Dict[str, Any]]:
        """Search with context-aware matching"""
        try:
            if not query or not self.fish_data:
                logger.info("Empty query or no fish data")
                return []
            
            # Check cache
            cache_key = f"{query.lower()}_{limit}_{min_score}"
            if (self.cache_timestamp and 
                datetime.now() - self.cache_timestamp < self.cache_duration and 
                cache_key in self.cache):
                logger.info(f"Cache hit for: {query}")
                return self.cache[cache_key]
            
            # Expand query terms with context awareness
            expanded_terms, is_attribute_search = self.expand_query_terms(query)
            self._last_expanded_terms = expanded_terms
            
            logger.info(f"Query: '{query}' (attribute search: {is_attribute_search})")
            logger.info(f"Expanded to: {sorted(list(expanded_terms)[:15])}...")
            
            # Calculate scores
            doc_scores = defaultdict(float)
            matched_terms = defaultdict(set)
            matched_fields = defaultdict(set)
            
            terms_found = 0
            for term in expanded_terms:
                if term in self.inverted_index:
                    terms_found += 1
                    for doc_id in self.inverted_index[term]:
                        score = self.calculate_bm25_score(term, doc_id, is_attribute_search)
                        doc_scores[doc_id] += score
                        matched_terms[doc_id].add(term)
                        
                        # Track matched fields
                        fish = self.fish_data[doc_id]
                        for field_name in self.field_weights.keys():
                            if field_name in fish and fish[field_name]:
                                field_tokens = self.preprocess_text(str(fish[field_name]), field_name)
                                if term in field_tokens:
                                    matched_fields[doc_id].add(field_name)
            
            logger.info(f"Found {terms_found}/{len(expanded_terms)} terms in index")
            logger.info(f"Matched {len(doc_scores)} documents")
            
            if not doc_scores:
                return []
            
            # Build results with metadata
            results = []
            for doc_id, score in doc_scores.items():
                if score >= min_score:
                    fish_data = self.fish_data[doc_id].copy()
                    fish_data['search_score'] = round(score, 4)
                    fish_data['matched_terms'] = sorted(list(matched_terms[doc_id])[:10])  # Limit for readability
                    fish_data['matched_fields'] = sorted(list(matched_fields[doc_id]))
                    
                    # Add relevance indicators
                    if is_attribute_search:
                        # Check if temperament actually matches
                        temperament = self.normalize_term(str(fish_data.get('temperament', '')))
                        query_normalized = self.normalize_term(query)
                        fish_data['temperament_match'] = any(
                            term in temperament or temperament in term 
                            for term in expanded_terms if self.is_attribute_keyword(term)
                        )
                    
                    results.append(fish_data)
            
            # Sort by score and limit
            results.sort(key=lambda x: x['search_score'], reverse=True)
            
            # If this is an attribute search, re-rank to penalize mismatches
            if is_attribute_search and results:
                # Separate results by attribute match
                good_matches = [r for r in results if r.get('temperament_match', False)]
                weak_matches = [r for r in results if not r.get('temperament_match', False)]
                
                # Concatenate: good matches first, then weak matches
                results = good_matches + weak_matches
            
            results = results[:limit]
            
            if results:
                logger.info(f"Top result: {results[0].get('common_name')} "
                           f"(score: {results[0]['search_score']:.4f}, "
                           f"temperament: {results[0].get('temperament', 'N/A')})")
            
            logger.info(f"Returning {len(results)} results")
            
            # Cache results
            self.cache[cache_key] = results
            self.cache_timestamp = datetime.now()
            
            return results
            
        except Exception as e:
            logger.error(f"Search failed for '{query}': {str(e)}", exc_info=True)
            return []
    
    def filter_results(self, results: List[Dict[str, Any]], 
                      filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Apply post-search filters"""
        if not filters:
            return results
        
        filtered = []
        for fish in results:
            match = True
            
            # Filter by temperament
            if 'temperament' in filters:
                expected = self.normalize_term(filters['temperament'])
                actual = self.normalize_term(str(fish.get('temperament', '')))
                if expected not in actual:
                    match = False
            
            # Filter by water type
            if 'water_type' in filters:
                expected = self.normalize_term(filters['water_type'])
                actual = self.normalize_term(str(fish.get('water_type', '')))
                if expected not in actual:
                    match = False
            
            # Filter by care level
            if 'care_level' in filters:
                expected = self.normalize_term(filters['care_level'])
                actual = self.normalize_term(str(fish.get('care_level', '')))
                if expected not in actual:
                    match = False
            
            # Size range filter
            if 'max_size' in filters:
                fish_size = fish.get('max_size_(cm)', 0)
                if isinstance(fish_size, (int, float)) and fish_size > filters['max_size']:
                    match = False
            
            # Tank size filter
            if 'min_tank_size' in filters:
                tank_size = fish.get('minimum_tank_size_(l)', 0)
                if isinstance(tank_size, (int, float)) and tank_size > filters['min_tank_size']:
                    match = False
            
            if match:
                filtered.append(fish)
        
        return filtered
    
    def calculate_edit_distance(self, s1: str, s2: str, max_distance: int = 2) -> int:
        """
        Calculate Levenshtein distance with early termination
        Returns max_distance + 1 if distance exceeds threshold
        """
        len1, len2 = len(s1), len(s2)
        
        # Quick checks
        if abs(len1 - len2) > max_distance:
            return max_distance + 1
        
        if len1 > len2:
            s1, s2 = s2, s1
            len1, len2 = len2, len1
        
        # Initialize distance matrix (single row optimization)
        previous_row = list(range(len2 + 1))
        
        for i in range(len1):
            current_row = [i + 1]
            min_dist = i + 1
            
            for j in range(len2):
                # Calculate costs
                delete_cost = previous_row[j + 1] + 1
                insert_cost = current_row[j] + 1
                substitute_cost = previous_row[j] + (0 if s1[i] == s2[j] else 1)
                
                current_row.append(min(delete_cost, insert_cost, substitute_cost))
                min_dist = min(min_dist, current_row[-1])
            
            # Early termination if entire row exceeds threshold
            if min_dist > max_distance:
                return max_distance + 1
            
            previous_row = current_row
        
        return previous_row[len2]
    
    def find_typo_corrections(self, query: str, max_suggestions: int = 5) -> List[Tuple[str, int]]:
        """
        Find potential typo corrections using edit distance
        Returns list of (correction, distance) tuples
        """
        query_lower = self.normalize_term(query)
        corrections = []
        
        # Check attribute keywords first (highest priority)
        for keyword in self.attribute_keywords:
            distance = self.calculate_edit_distance(query_lower, keyword, max_distance=2)
            if distance <= 2 and distance > 0:  # Only suggest if there's a typo
                corrections.append((keyword, distance))
        
        # Check common words from fish names
        seen_words = set()
        for fish in self.fish_data:
            if 'common_name' in fish and fish['common_name']:
                words = self.normalize_term(fish['common_name']).split()
                for word in words:
                    if len(word) >= 3 and word not in seen_words:
                        seen_words.add(word)
                        distance = self.calculate_edit_distance(query_lower, word, max_distance=2)
                        if distance <= 2 and distance > 0:
                            corrections.append((word, distance))
        
        # Sort by distance (closest first) and frequency
        corrections.sort(key=lambda x: (x[1], len(x[0])))
        
        return corrections[:max_suggestions]
    
    def get_autocomplete_suggestions(self, query: str, limit: int = 10) -> Dict[str, Any]:
        """
        Get smart autocomplete suggestions with typo correction
        Returns dict with suggestions, corrections, and metadata
        """
        if not query or len(query) < 1:
            return {
                'suggestions': [],
                'corrections': [],
                'query': query,
                'suggestion_count': 0
            }
        
        query_lower = self.normalize_term(query)
        suggestions = []
        seen = set()
        
        # Helper to add unique suggestion with metadata
        def add_suggestion(text: str, match_type: str, priority: int):
            text_lower = text.lower()
            if text_lower not in seen:
                seen.add(text_lower)
                suggestions.append({
                    'text': text,
                    'match_type': match_type,
                    'priority': priority,
                    'starts_with_query': text_lower.startswith(query_lower)
                })
        
        # Priority 1: Exact prefix matches with attribute keywords (highest priority)
        for main_term in self.synonyms.keys():
            if main_term.startswith(query_lower):
                add_suggestion(main_term.title(), 'attribute_keyword', 1)
        
        # Priority 2: Synonym prefix matches
        for main_term, synonyms in self.synonyms.items():
            for syn in synonyms:
                if syn.startswith(query_lower):
                    add_suggestion(syn.title(), 'attribute_synonym', 2)
        
        # Priority 3: Fish names (prefix match for short queries, contains for longer)
        for fish in self.fish_data:
            if 'common_name' in fish and fish['common_name']:
                name = str(fish['common_name'])
                name_lower = name.lower()
                
                # Prefix match (highest priority for names)
                if name_lower.startswith(query_lower):
                    add_suggestion(name, 'fish_name_prefix', 3)
                # Contains match (only for queries 3+ chars)
                elif len(query_lower) >= 3 and query_lower in name_lower:
                    add_suggestion(name, 'fish_name_contains', 5)
                # Word boundary match (e.g., "bet" matches "Siamese Betta")
                elif len(query_lower) >= 3:
                    words = name_lower.split()
                    for word in words:
                        if word.startswith(query_lower):
                            add_suggestion(name, 'fish_name_word', 4)
                            break
        
        # Priority 4: Other attribute values
        priority_fields = ['temperament', 'water_type', 'care_level', 'diet', 'social_behavior']
        for fish in self.fish_data:
            for field in priority_fields:
                if field in fish and fish[field]:
                    value = str(fish[field])
                    value_lower = value.lower()
                    
                    if value_lower.startswith(query_lower):
                        add_suggestion(value, f'attribute_{field}', 6)
                    elif len(query_lower) >= 3 and query_lower in value_lower:
                        add_suggestion(value, f'attribute_{field}_contains', 7)
        
        # Sort suggestions by priority and relevance
        suggestions.sort(key=lambda x: (
            x['priority'],  # Primary sort by priority
            not x['starts_with_query'],  # Prefix matches first
            len(x['text']),  # Shorter suggestions first
            x['text'].lower()  # Alphabetical
        ))
        
        # Get top suggestions
        top_suggestions = [s['text'] for s in suggestions[:limit]]
        
        # Find typo corrections (only if we have few suggestions or query is 3+ chars)
        corrections = []
        if len(top_suggestions) < 3 and len(query_lower) >= 3:
            typo_results = self.find_typo_corrections(query_lower, max_suggestions=3)
            corrections = [
                {
                    'suggestion': correction,
                    'distance': distance,
                    'message': f"Did you mean '{correction}'?"
                }
                for correction, distance in typo_results
            ]
        
        return {
            'suggestions': top_suggestions,
            'corrections': corrections,
            'query': query,
            'suggestion_count': len(top_suggestions),
            'has_corrections': len(corrections) > 0
        }
    
    def get_last_expanded_terms(self) -> set:
        """Get expanded terms from last search"""
        return self._last_expanded_terms


# Global instance
bm25_service = BM25SearchService()

async def initialize_bm25_service(fish_data: List[Dict[str, Any]]):
    """Initialize the BM25 service"""
    bm25_service.build_index(fish_data)
    logger.info("BM25 service initialized")

async def search_fish(query: str, limit: int = 100, min_score: float = 0.01, 
                     filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """Search fish with optional filters"""
    results = bm25_service.search(query, limit, min_score)
    if filters:
        results = bm25_service.filter_results(results, filters)
    return results

async def get_autocomplete_suggestions(query: str, limit: int = 10) -> Dict[str, Any]:
    """Get autocomplete suggestions with typo correction"""
    return bm25_service.get_autocomplete_suggestions(query, limit)