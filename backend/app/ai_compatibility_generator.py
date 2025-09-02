#!/usr/bin/env python3
"""
AI-Powered Compatibility Requirements Generator

This module uses HuggingFace models to dynamically generate compatibility requirements
for fish species instead of relying on hardcoded rules.
"""

import asyncio
import json
import logging
import os
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime, timezone

# HuggingFace imports
try:
    from transformers import pipeline, AutoTokenizer, AutoModelForSequenceGeneration
    from huggingface_hub import InferenceClient
    HUGGINGFACE_AVAILABLE = True
except ImportError:
    HUGGINGFACE_AVAILABLE = False
    logging.warning("HuggingFace not available. Install with: pip install transformers huggingface_hub")

logger = logging.getLogger(__name__)

class AICompatibilityGenerator:
    """AI-powered compatibility requirements generator using HuggingFace models"""
    
    def __init__(self):
        self.hf_available = HUGGINGFACE_AVAILABLE
        self.client = None
        self.text_generator = None
        
        if self.hf_available:
            self._initialize_models()
    
    def _initialize_models(self):
        """Initialize HuggingFace models and client"""
        try:
            # Use a free, lightweight model for text generation
            model_name = "microsoft/DialoGPT-small"  # Free and lightweight
            
            # Initialize tokenizer and model
            self.tokenizer = AutoTokenizer.from_pretrained(model_name)
            self.model = AutoModelForSequenceGeneration.from_pretrained(model_name)
            
            # Initialize text generation pipeline
            self.text_generator = pipeline(
                "text-generation",
                model=model_name,
                tokenizer=model_name,
                max_length=100,
                do_sample=True,
                temperature=0.7,
                pad_token_id=self.tokenizer.eos_token_id
            )
            
            # Initialize HuggingFace inference client for alternative models
            self.client = InferenceClient()
            
            logger.info("✅ HuggingFace models initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize HuggingFace models: {e}")
            self.hf_available = False
    
    def generate_compatibility_prompt(self, fish1: Dict, fish2: Dict) -> str:
        """Generate a prompt for AI compatibility analysis"""
        fish1_name = fish1.get('common_name', 'Unknown')
        fish2_name = fish2.get('common_name', 'Unknown')
        
        fish1_traits = self._extract_fish_traits(fish1)
        fish2_traits = self._extract_fish_traits(fish2)
        
        prompt = f"""
        Fish Compatibility Analysis:
        
        Fish 1: {fish1_name}
        Traits: {fish1_traits}
        
        Fish 2: {fish2_name}
        Traits: {fish2_traits}
        
        Based on these characteristics, analyze their compatibility and provide:
        1. Compatibility level (compatible/conditional/incompatible)
        2. Specific reasons for compatibility decision
        3. Required conditions if conditional
        4. Special care requirements
        
        Response format:
        - Level: [compatible/conditional/incompatible]
        - Reasons: [list of reasons]
        - Conditions: [list of conditions if conditional]
        - Care: [special care requirements]
        """
        
        return prompt.strip()
    
    def _extract_fish_traits(self, fish: Dict) -> str:
        """Extract relevant traits from fish data"""
        traits = []
        
        # Basic characteristics
        if fish.get('water_type'):
            traits.append(f"Water: {fish['water_type']}")
        
        if fish.get('temperament'):
            traits.append(f"Temperament: {fish['temperament']}")
        
        if fish.get('max_size_(cm)'):
            traits.append(f"Size: {fish['max_size_(cm)']}cm")
        
        if fish.get('social_behavior'):
            traits.append(f"Behavior: {fish['social_behavior']}")
        
        if fish.get('care_level'):
            traits.append(f"Care: {fish['care_level']}")
        
        # Additional characteristics
        if fish.get('diet'):
            traits.append(f"Diet: {fish['diet']}")
        
        if fish.get('habitat'):
            traits.append(f"Habitat: {fish['habitat']}")
        
        return ", ".join(traits) if traits else "Limited information available"
    
    async def generate_compatibility_requirements(self, fish1: Dict, fish2: Dict) -> Dict[str, Any]:
        """Generate AI-powered compatibility requirements for two fish"""
        if not self.hf_available:
            return self._fallback_compatibility(fish1, fish2)
        
        try:
            # Generate prompt
            prompt = self.generate_compatibility_prompt(fish1, fish2)
            
            # Generate AI response
            ai_response = await self._generate_ai_response(prompt)
            
            # Parse AI response
            parsed_response = self._parse_ai_response(ai_response)
            
            # Validate and enhance response
            enhanced_response = self._enhance_compatibility_response(
                parsed_response, fish1, fish2
            )
            
            logger.info(f"✅ AI-generated compatibility for {fish1.get('common_name')} + {fish2.get('common_name')}")
            return enhanced_response
            
        except Exception as e:
            logger.error(f"AI generation failed: {e}")
            return self._fallback_compatibility(fish1, fish2)
    
    async def _generate_ai_response(self, prompt: str) -> str:
        """Generate AI response using HuggingFace models"""
        try:
            # Try using the local pipeline first
            if self.text_generator:
                response = self.text_generator(prompt, max_length=200)[0]['generated_text']
                return response
            
            # Fallback to HuggingFace inference API
            elif self.client:
                response = await asyncio.to_thread(
                    self.client.text_generation,
                    prompt,
                    model="microsoft/DialoGPT-small",
                    max_new_tokens=100,
                    temperature=0.7
                )
                return response
            
            else:
                raise Exception("No AI models available")
                
        except Exception as e:
            logger.error(f"AI generation error: {e}")
            raise
    
    def _parse_ai_response(self, ai_response: str) -> Dict[str, Any]:
        """Parse the AI-generated response into structured data"""
        try:
            # Extract information from AI response
            lines = ai_response.split('\n')
            parsed = {
                'level': 'conditional',  # Default
                'reasons': [],
                'conditions': [],
                'care_requirements': []
            }
            
            for line in lines:
                line = line.strip().lower()
                
                if 'level:' in line:
                    if 'compatible' in line:
                        parsed['level'] = 'compatible'
                    elif 'incompatible' in line:
                        parsed['level'] = 'incompatible'
                    elif 'conditional' in line:
                        parsed['level'] = 'conditional'
                
                elif 'reasons:' in line:
                    # Extract reasons from the line
                    reasons_text = line.split('reasons:')[-1].strip()
                    if reasons_text:
                        parsed['reasons'].append(reasons_text)
                
                elif 'conditions:' in line:
                    # Extract conditions from the line
                    conditions_text = line.split('conditions:')[-1].strip()
                    if conditions_text:
                        parsed['conditions'].append(conditions_text)
                
                elif 'care:' in line:
                    # Extract care requirements from the line
                    care_text = line.split('care:')[-1].strip()
                    if care_text:
                        parsed['care_requirements'].append(care_text)
            
            return parsed
            
        except Exception as e:
            logger.error(f"Failed to parse AI response: {e}")
            return self._default_parsed_response()
    
    def _default_parsed_response(self) -> Dict[str, Any]:
        """Default response when AI parsing fails"""
        return {
            'level': 'conditional',
            'reasons': ['AI analysis incomplete - manual review recommended'],
            'conditions': ['Monitor behavior closely', 'Provide adequate space'],
            'care_requirements': ['Regular water quality checks', 'Observe fish interactions']
        }
    
    def _enhance_compatibility_response(self, parsed: Dict, fish1: Dict, fish2: Dict) -> Dict[str, Any]:
        """Enhance the parsed AI response with additional context"""
        fish1_name = fish1.get('common_name', 'Unknown')
        fish2_name = fish2.get('common_name', 'Unknown')
        
        # Add basic compatibility logic as fallback
        basic_compatibility = self._calculate_basic_compatibility(fish1, fish2)
        
        # Merge AI response with basic logic
        enhanced = {
            'fish1_name': fish1_name,
            'fish2_name': fish2_name,
            'compatibility_level': parsed['level'],
            'is_compatible': parsed['level'] in ['compatible', 'conditional'],
            'compatibility_reasons': parsed['reasons'] or basic_compatibility['reasons'],
            'conditions': parsed['conditions'] or basic_compatibility['conditions'],
            'care_requirements': parsed['care_requirements'] or basic_compatibility['care_requirements'],
            'ai_generated': True,
            'confidence_score': 0.8 if parsed['reasons'] else 0.6,
            'generation_method': 'ai_powered_with_basic_logic',
            'calculated_at': datetime.now(timezone.utc).isoformat()
        }
        
        return enhanced
    
    def _calculate_basic_compatibility(self, fish1: Dict, fish2: Dict) -> Dict[str, Any]:
        """Calculate basic compatibility using simple logic as fallback"""
        fish1_name = fish1.get('common_name', 'Unknown')
        fish2_name = fish2.get('common_name', 'Unknown')
        
        reasons = []
        conditions = []
        care_requirements = []
        
        # Water type compatibility
        water1 = str(fish1.get('water_type', '')).lower()
        water2 = str(fish2.get('water_type', '')).lower()
        
        if water1 != water2:
            if 'saltwater' in water1 and 'freshwater' in water2:
                reasons.append(f"{fish1_name} (saltwater) cannot live with {fish2_name} (freshwater)")
                return {
                    'level': 'incompatible',
                    'reasons': reasons,
                    'conditions': [],
                    'care_requirements': []
                }
            elif 'freshwater' in water1 and 'saltwater' in water2:
                reasons.append(f"{fish1_name} (freshwater) cannot live with {fish2_name} (saltwater)")
                return {
                    'level': 'incompatible',
                    'reasons': reasons,
                    'conditions': [],
                    'care_requirements': []
                }
        
        # Temperament compatibility
        temperament1 = str(fish1.get('temperament', '')).lower()
        temperament2 = str(fish2.get('temperament', '')).lower()
        
        if 'aggressive' in temperament1 and 'peaceful' in temperament2:
            reasons.append(f"{fish1_name} (aggressive) may harm {fish2_name} (peaceful)")
            conditions.extend([
                "Large tank with hiding spots",
                "Monitor for aggression",
                "Be prepared to separate if needed"
            ])
        elif 'aggressive' in temperament2 and 'peaceful' in temperament1:
            reasons.append(f"{fish2_name} (aggressive) may harm {fish1_name} (peaceful)")
            conditions.extend([
                "Large tank with hiding spots",
                "Monitor for aggression",
                "Be prepared to separate if needed"
            ])
        
        # Size compatibility
        size1 = float(fish1.get('max_size_(cm)', 0) or 0)
        size2 = float(fish2.get('max_size_(cm)', 0) or 0)
        
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio > 4:
                reasons.append(f"Significant size difference between {fish1_name} and {fish2_name}")
                conditions.extend([
                    "Provide adequate hiding spots",
                    "Monitor for bullying",
                    "Ensure sufficient tank space"
                ])
        
        # Social behavior
        social1 = str(fish1.get('social_behavior', '')).lower()
        social2 = str(fish2.get('social_behavior', '')).lower()
        
        if 'solitary' in social1 and 'schooling' in social2:
            reasons.append(f"{fish1_name} is solitary while {fish2_name} prefers schooling")
            conditions.extend([
                "Provide separate territories",
                "Monitor for stress",
                "Ensure adequate space"
            ])
        
        # Determine level based on conditions
        if conditions:
            level = 'conditional'
        elif reasons:
            level = 'incompatible'
        else:
            level = 'compatible'
            reasons.append(f"{fish1_name} and {fish2_name} appear compatible based on basic characteristics")
        
        # Add general care requirements
        care_requirements.extend([
            "Regular water quality monitoring",
            "Provide appropriate diet for both species",
            "Maintain proper tank parameters"
        ])
        
        return {
            'level': level,
            'reasons': reasons,
            'conditions': conditions,
            'care_requirements': care_requirements
        }
    
    def _fallback_compatibility(self, fish1: Dict, fish2: Dict) -> Dict[str, Any]:
        """Fallback compatibility when AI is not available"""
        basic = self._calculate_basic_compatibility(fish1, fish2)
        
        return {
            'fish1_name': fish1.get('common_name', 'Unknown'),
            'fish2_name': fish2.get('common_name', 'Unknown'),
            'compatibility_level': basic['level'],
            'is_compatible': basic['level'] in ['compatible', 'conditional'],
            'compatibility_reasons': basic['reasons'],
            'conditions': basic['conditions'],
            'care_requirements': basic['care_requirements'],
            'ai_generated': False,
            'confidence_score': 0.7,
            'generation_method': 'basic_logic_fallback',
            'calculated_at': datetime.now(timezone.utc).isoformat()
        }
    
    async def generate_fish_specific_requirements(self, fish: Dict) -> Dict[str, Any]:
        """Generate AI-powered requirements for a specific fish species"""
        if not self.hf_available:
            return self._fallback_fish_requirements(fish)
        
        try:
            fish_name = fish.get('common_name', 'Unknown')
            traits = self._extract_fish_traits(fish)
            
            prompt = f"""
            Fish Care Requirements Analysis:
            
            Fish: {fish_name}
            Traits: {traits}
            
            Provide detailed care requirements:
            1. Tank size recommendations
            2. Water parameters
            3. Diet requirements
            4. Social needs
            5. Special considerations
            
            Response format:
            - Tank: [tank size and setup]
            - Water: [water parameters]
            - Diet: [diet requirements]
            - Social: [social behavior needs]
            - Special: [special considerations]
            """
            
            ai_response = await self._generate_ai_response(prompt)
            parsed = self._parse_fish_requirements(ai_response)
            
            return {
                'fish_name': fish_name,
                'tank_requirements': parsed.get('tank', 'Standard aquarium setup'),
                'water_parameters': parsed.get('water', 'Standard parameters'),
                'diet_requirements': parsed.get('diet', 'Varied diet'),
                'social_needs': parsed.get('social', 'Standard social needs'),
                'special_considerations': parsed.get('special', 'No special requirements'),
                'ai_generated': True,
                'confidence_score': 0.8,
                'generated_at': datetime.now(timezone.utc).isoformat()
            }
            
        except Exception as e:
            logger.error(f"Failed to generate fish requirements: {e}")
            return self._fallback_fish_requirements(fish)
    
    def _parse_fish_requirements(self, ai_response: str) -> Dict[str, str]:
        """Parse AI-generated fish requirements"""
        parsed = {}
        lines = ai_response.split('\n')
        
        for line in lines:
            line = line.strip().lower()
            if 'tank:' in line:
                parsed['tank'] = line.split('tank:')[-1].strip()
            elif 'water:' in line:
                parsed['water'] = line.split('water:')[-1].strip()
            elif 'diet:' in line:
                parsed['diet'] = line.split('diet:')[-1].strip()
            elif 'social:' in line:
                parsed['social'] = line.split('social:')[-1].strip()
            elif 'special:' in line:
                parsed['special'] = line.split('special:')[-1].strip()
        
        return parsed
    
    def _fallback_fish_requirements(self, fish: Dict) -> Dict[str, Any]:
        """Fallback fish requirements when AI is not available"""
        return {
            'fish_name': fish.get('common_name', 'Unknown'),
            'tank_requirements': 'Standard aquarium setup recommended',
            'water_parameters': 'Standard freshwater/saltwater parameters',
            'diet_requirements': 'Varied diet appropriate for species',
            'social_needs': 'Standard social behavior for species',
            'special_considerations': 'No special requirements identified',
            'ai_generated': False,
            'confidence_score': 0.6,
            'generated_at': datetime.now(timezone.utc).isoformat()
        }

# Global instance
ai_generator = AICompatibilityGenerator()
