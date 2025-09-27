#!/usr/bin/env python3
"""
Enhanced Compatibility Integration

Integrates the enhanced fish compatibility system with existing API endpoints.
Provides backward compatibility while using the new comprehensive attribute system.
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from .models.enhanced_fish_model import (
    EnhancedFishData, WaterType, Temperament, SocialBehavior, 
    ActivityLevel, TankZone, Diet, FinVulnerability, BreedingBehavior,
    check_enhanced_compatibility
)

logger = logging.getLogger(__name__)

def convert_db_fish_to_enhanced(fish_data: Dict) -> EnhancedFishData:
    """Convert database fish record to EnhancedFishData model"""
    
    def safe_enum_convert(value, enum_class, default=None):
        """Safely convert string to enum"""
        if not value:
            return default
        try:
            return enum_class(value)
        except (ValueError, TypeError):
            return default
    
    return EnhancedFishData(
        common_name=fish_data.get('common_name', ''),
        scientific_name=fish_data.get('scientific_name', ''),
        
        # Water parameters
        water_type=safe_enum_convert(fish_data.get('water_type'), WaterType),
        temperature_min=float(fish_data.get('temperature_min', 0)) if fish_data.get('temperature_min') else 0.0,
        temperature_max=float(fish_data.get('temperature_max', 0)) if fish_data.get('temperature_max') else 0.0,
        ph_min=float(fish_data.get('ph_min', 0)) if fish_data.get('ph_min') else 0.0,
        ph_max=float(fish_data.get('ph_max', 0)) if fish_data.get('ph_max') else 0.0,
        hardness_min=float(fish_data.get('hardness_min', 0)) if fish_data.get('hardness_min') else 0.0,
        hardness_max=float(fish_data.get('hardness_max', 0)) if fish_data.get('hardness_max') else 0.0,
        
        # Behavioral traits
        temperament=safe_enum_convert(fish_data.get('temperament'), Temperament),
        social_behavior=safe_enum_convert(fish_data.get('social_behavior'), SocialBehavior),
        activity_level=safe_enum_convert(fish_data.get('activity_level'), ActivityLevel),
        
        # Physical characteristics
        max_size_cm=float(fish_data.get('max_size_(cm)', 0)) if fish_data.get('max_size_(cm)') else 0.0,
        min_tank_size_l=float(fish_data.get('minimum_tank_size_(l)', 0)) if fish_data.get('minimum_tank_size_(l)') else 0.0,
        tank_zone=safe_enum_convert(fish_data.get('tank_zone'), TankZone),
        
        # Diet and feeding
        diet=safe_enum_convert(fish_data.get('diet'), Diet),
        
        # Compatibility factors
        fin_vulnerability=safe_enum_convert(fish_data.get('fin_vulnerability'), FinVulnerability),
        fin_nipper=bool(fish_data.get('fin_nipper', False)),
        breeding_behavior=safe_enum_convert(fish_data.get('breeding_behavior'), BreedingBehavior),
        
        # Special requirements
        reef_safe=fish_data.get('reef_safe'),
        schooling_min_number=int(fish_data.get('schooling_min_number', 1)) if fish_data.get('schooling_min_number') else 1,
        territorial_space_cm=float(fish_data.get('territorial_space_cm', 0)) if fish_data.get('territorial_space_cm') else 0.0,
        hiding_spots_required=bool(fish_data.get('hiding_spots_required', False)),
        strong_current_needed=bool(fish_data.get('strong_current_needed', False)),
        special_diet_requirements=fish_data.get('special_diet_requirements', ''),
        
        # Care level
        care_level=fish_data.get('care_level', ''),
        
        # Data quality
        confidence_score=float(fish_data.get('confidence_score', 0.5)) if fish_data.get('confidence_score') else 0.5,
        sources=fish_data.get('data_sources', []) or [],
        last_updated=str(fish_data.get('last_updated', ''))
    )

def check_special_compatibility_cases(fish1_data: Dict, fish2_data: Dict) -> Optional[Tuple[str, List[str], List[str]]]:
    """Check for special case fish with known real-world compatibility patterns"""
    name1 = str(fish1_data.get('common_name', '')).lower()
    name2 = str(fish2_data.get('common_name', '')).lower()
    
    # Betta compatibility - can work with specific peaceful fish
    if "betta" in name1 or "betta" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "betta" in name1 else name1
            other_fish_data = fish2_data if "betta" in name1 else fish1_data
            
            # Betta-compatible species
            betta_compatible = [
                "corydoras", "cory", "kuhli loach", "neon tetra", "ember tetra",
                "harlequin rasbora", "celestial pearl danio", "otocinclus",
                "mystery snail", "nerite snail", "cherry shrimp"
            ]
            
            temperament = str(other_fish_data.get('temperament', '')).lower()
            is_peaceful = "peaceful" in temperament
            is_compatible_species = any(compatible in other_fish for compatible in betta_compatible)
            
            if is_peaceful and is_compatible_species:
                return ("conditional", 
                       [f"Your betta can live with {other_fish.title()}, but you'll need to create the right environment"],
                       ["Use a tank that's at least 20 gallons - smaller tanks increase aggression",
                        "Watch your fish closely for the first few weeks and be ready to separate them if needed",
                        "Only add very calm fish that won't nip at your betta's beautiful fins"])
            else:
                return ("incompatible",
                       [f"Bettas need very specific tankmates - {other_fish.title()} is not suitable for your betta's peaceful nature"],
                       [])
    
    # Flowerhorn compatibility - only with other large aggressive cichlids
    elif "flowerhorn" in name1 or "flowerhorn" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "flowerhorn" in name1 else name1
            other_fish_data = fish2_data if "flowerhorn" in name1 else fish1_data
            
            flowerhorn_compatible = [
                "oscar", "jack dempsey", "texas cichlid", "green terror",
                "electric blue jack dempsey", "pleco", "common pleco"
            ]
            
            is_large_aggressive = any(compatible in other_fish for compatible in flowerhorn_compatible)
            size = float(other_fish_data.get('max_size_(cm)', 0) or 0)
            
            if is_large_aggressive and size > 15:
                return ("conditional",
                       [f"Flowerhorn can potentially live with {other_fish.title()}, but this is very risky"],
                       ["You'll need an extremely large tank (75+ gallons per fish) to reduce fighting",
                        "Even with proper setup, these fish may still fight - be prepared for this",
                        "Watch your fish constantly and have a backup plan to separate them",
                        "Consider that Flowerhorn often do better when kept alone"])
            else:
                return ("incompatible",
                       [f"Flowerhorn are extremely aggressive and can only live with other large, tough fish - {other_fish.title()} won't survive"],
                       [])
    
    # Dottyback compatibility - with other semi-aggressive marine fish
    elif "dottyback" in name1 or "dottyback" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "dottyback" in name1 else name1
            other_fish_data = fish2_data if "dottyback" in name1 else fish1_data
            
            # Check water type compatibility first
            water1 = str(fish1_data.get('water_type', '')).lower()
            water2 = str(fish2_data.get('water_type', '')).lower()
            
            if "saltwater" in water1 and "saltwater" in water2:
                dottyback_compatible = [
                    "damselfish", "clownfish", "wrasse", "pseudochromis", "goby",
                    "cardinalfish", "anthias", "tang", "royal gramma"
                ]
                
                temperament = str(other_fish_data.get('temperament', '')).lower()
                is_marine_compatible = any(compatible in other_fish for compatible in dottyback_compatible)
                is_semi_aggressive = "semi" in temperament or "aggressive" in temperament
                
                if is_marine_compatible and (is_semi_aggressive or "peaceful" in temperament):
                    return ("conditional",
                           [f"Dottyback can live with {other_fish.title()} in a proper saltwater setup"],
                           ["Use a saltwater tank that's at least 30 gallons to give them enough space",
                            "Dottyback can be territorial, so arrange plenty of hiding spots and territories",
                            "Don't mix them with very shy fish or large predators"])
                else:
                    return ("incompatible",
                           [f"Dottyback have strong personalities that clash with {other_fish.title()}"],
                           [])
            else:
                return ("incompatible",
                       ["Dottyback are saltwater fish and cannot live with freshwater fish - their needs are completely different"],
                       [])
    
    return None  # No special case, use general logic

def check_enhanced_fish_compatibility(fish1_data: Dict, fish2_data: Dict) -> Tuple[str, List[str], List[str]]:
    """
    Check compatibility using enhanced system with fallback to legacy system
    
    Returns:
        - compatibility_level: 'compatible', 'conditional', 'incompatible'
        - reasons: List of compatibility reasons/issues
        - conditions: List of conditions for conditional compatibility
    """
    try:
        # First check for special case fish compatibility
        special_result = check_special_compatibility_cases(fish1_data, fish2_data)
        if special_result:
            return special_result
        # Convert to enhanced models
        fish1_enhanced = convert_db_fish_to_enhanced(fish1_data)
        fish2_enhanced = convert_db_fish_to_enhanced(fish2_data)
        
        # Check if we have enough enhanced data to make a determination
        fish1_has_enhanced = (
            fish1_enhanced.water_type is not None and
            fish1_enhanced.temperament is not None and
            fish1_enhanced.temperature_min > 0
        )
        
        fish2_has_enhanced = (
            fish2_enhanced.water_type is not None and
            fish2_enhanced.temperament is not None and
            fish2_enhanced.temperature_min > 0
        )
        
        if fish1_has_enhanced and fish2_has_enhanced:
            # Use enhanced compatibility system
            logger.info(f"Using enhanced compatibility for {fish1_enhanced.common_name} + {fish2_enhanced.common_name}")
            compatibility, reasons, conditions = check_enhanced_compatibility(fish1_enhanced, fish2_enhanced)
            return compatibility, reasons, conditions
        else:
            # Fall back to legacy system
            logger.info(f"Falling back to legacy compatibility for {fish1_data.get('common_name')} + {fish2_data.get('common_name')}")
            from .conditional_compatibility import check_conditional_compatibility
            compatibility, reasons, conditions = check_conditional_compatibility(fish1_data, fish2_data)
            
            # Make the legacy system more strict - if we don't have enough data, be more conservative
            if not fish1_data.get('temperament') or not fish2_data.get('temperament'):
                logger.warning(f"Insufficient data for {fish1_data.get('common_name')} + {fish2_data.get('common_name')} - being conservative")
                if compatibility == "compatible":
                    compatibility = "conditional"
                if not conditions:
                    conditions = ["Watch your fish very carefully when you first introduce them to each other"]
                if not reasons:
                    reasons = ["We don't have enough information about these fish to give you a complete compatibility assessment"]
            
            return compatibility, reasons, conditions
            
    except Exception as e:
        logger.error(f"Enhanced compatibility check failed: {str(e)}")
        # Fall back to legacy system on error
        from .conditional_compatibility import check_conditional_compatibility
        return check_conditional_compatibility(fish1_data, fish2_data)

def get_compatibility_summary(fish1_name: str, fish2_name: str, compatibility_level: str, 
                            reasons: List[str], conditions: List[str]) -> Dict[str, Any]:
    """Generate a standardized compatibility result summary"""
    
    compatibility_display = {
        "compatible": "Compatible",
        "conditional": "Conditionally Compatible", 
        "incompatible": "Not Compatible"
    }.get(compatibility_level, "Unknown")
    
    result = {
        "pair": [fish1_name, fish2_name],
        "compatibility": compatibility_display,
        "compatibility_level": compatibility_level,
        "reasons": reasons if reasons else ["Compatibility assessed using comprehensive fish attributes"]
    }
    
    if conditions and compatibility_level == "conditional":
        result["conditions"] = conditions
    
    return result

def check_same_species_enhanced(fish_name: str, fish_data: Dict) -> Tuple[bool, str]:
    """Enhanced same-species compatibility check"""
    try:
        fish_enhanced = convert_db_fish_to_enhanced(fish_data)
        
        # Check enhanced social behavior
        if fish_enhanced.social_behavior == SocialBehavior.SOLITARY:
            return False, f"{fish_name} prefers to be kept alone"
        
        if fish_enhanced.social_behavior == SocialBehavior.TERRITORIAL and fish_enhanced.temperament in [Temperament.AGGRESSIVE, Temperament.TERRITORIAL]:
            return False, f"{fish_name} is territorial and aggressive - should be kept alone"
        
        # Check if it's a highly aggressive species
        highly_aggressive = [
            "betta", "siamese fighting fish", "paradise fish", 
            "flowerhorn", "wolf cichlid", "jaguar cichlid"
        ]
        
        if any(aggressive in fish_name.lower() for aggressive in highly_aggressive):
            return False, f"{fish_name} is highly aggressive and should be kept alone"
        
        # If schooling, check minimum numbers
        if fish_enhanced.social_behavior == SocialBehavior.SCHOOLING:
            min_number = fish_enhanced.schooling_min_number
            if min_number > 1:
                return True, f"{fish_name} should be kept in groups of at least {min_number}"
        
        return True, f"{fish_name} can generally be kept with others of the same species"
        
    except Exception as e:
        logger.error(f"Enhanced same-species check failed: {str(e)}")
        # Fall back to legacy system
        from .compatibility_logic import can_same_species_coexist
        return can_same_species_coexist(fish_name, fish_data)

def get_enhanced_tankmate_compatibility_info(fish_data: Dict) -> Dict[str, Any]:
    """Get enhanced compatibility information for tankmate recommendations"""
    try:
        fish_enhanced = convert_db_fish_to_enhanced(fish_data)
        
        # Determine compatibility based on real-world aquarium keeping practices
        fish_name_lower = fish_enhanced.common_name.lower()
        
        # Fish that are truly incompatible with any tankmates (public aquarium only)
        public_aquarium_only = [
            "hammerhead shark", "great white", "tiger shark", "whale shark",
            "manta ray", "stingray", "barracuda", "moray eel"
        ]
        
        is_public_aquarium_only = any(name in fish_name_lower for name in public_aquarium_only)
        if is_public_aquarium_only:
            return {
                "allow_tankmates": False,
                "reason": "This fish is designed for large public aquariums and requires specialized care that's not suitable for home tanks",
                "special_requirements": ["Requires massive public aquarium setup"]
            }
        
        # Fish that need very specific, limited tankmate options
        extremely_limited_compatibility = [
            "wolf cichlid", "jaguar cichlid", "red devil", "midas cichlid"
        ]
        
        is_extremely_limited = any(name in fish_name_lower for name in extremely_limited_compatibility)
        if is_extremely_limited:
            return {
                "allow_tankmates": True,
                "reason": "These fish are extremely aggressive and will likely kill or severely injure other fish",
                "special_requirements": ["Requires very large tank (100+ gallons)", "Only with other large aggressive fish"],
                "limited_compatibility": True
            }
        
        # Special handling for specific fish based on real aquarium compatibility
        
        # Betta - can have tankmates but very specific requirements
        if "betta" in fish_name_lower:
            return {
                "allow_tankmates": True,
                "reason": "Your betta can have tankmates, but you need to choose very carefully - only peaceful fish that won't nip fins",
                "special_requirements": [
                    "Use a tank that's at least 20 gallons - smaller tanks increase aggression",
                    "Good with peaceful bottom dwellers like Corydoras and Kuhli loaches",
                    "Safe with snails and some shrimp",
                    "Never add aggressive fish, fin-nippers, or other bettas",
                    "Watch for any signs of aggression and be ready to separate immediately"
                ],
                "limited_compatibility": True
            }
        
        # Flowerhorn - very limited but possible tankmates
        if "flowerhorn" in fish_name_lower:
            return {
                "allow_tankmates": True,
                "reason": "Flowerhorn are extremely aggressive and can only live with other large, tough fish in massive tanks",
                "special_requirements": [
                    "You'll need an extremely large tank (75+ gallons per fish) to reduce fighting",
                    "Only compatible with other large aggressive cichlids like Oscars and Jack Dempseys",
                    "Large plecos might work as tankmates",
                    "Even with 'compatible' fish, fighting is very common",
                    "Often these fish do better when kept alone",
                    "Watch your fish constantly for any signs of aggression"
                ],
                "limited_compatibility": True
            }
        
        # Dottyback - marine semi-aggressive, has viable tankmates
        if "dottyback" in fish_name_lower:
            return {
                "allow_tankmates": True,
                "reason": "Dottyback are semi-aggressive marine fish that can live with other similar marine species",
                "special_requirements": [
                    "Use a saltwater tank that's at least 30 gallons to give them enough space",
                    "Good with other semi-aggressive marine fish",
                    "Works well with damsels, other pseudochromis, clownfish, and wrasses",
                    "Don't mix them with very shy fish or large predators",
                    "They can be territorial, but it's manageable with the right tank setup"
                ],
                "water_type_specific": "marine_only"
            }
        
        # Determine general special requirements
        special_requirements = []
        
        if fish_enhanced.schooling_min_number > 1:
            special_requirements.append(f"Keep in groups of {fish_enhanced.schooling_min_number}+")
        
        if fish_enhanced.territorial_space_cm > 30:
            special_requirements.append(f"Needs territory space of {fish_enhanced.territorial_space_cm}cm diameter")
        
        if fish_enhanced.hiding_spots_required:
            special_requirements.append("Requires hiding spots and caves")
        
        if fish_enhanced.reef_safe is False:
            special_requirements.append("Not reef safe - may nip corals")
        
        if fish_enhanced.special_diet_requirements:
            special_requirements.append(f"Special diet: {fish_enhanced.special_diet_requirements}")
        
        return {
            "allow_tankmates": True,
            "reason": "These fish should get along well with appropriate tankmates",
            "special_requirements": special_requirements,
            "care_level": fish_enhanced.care_level,
            "confidence_score": fish_enhanced.confidence_score
        }
        
    except Exception as e:
        logger.error(f"Enhanced tankmate info failed: {str(e)}")
        return {
            "allow_tankmates": True,
            "reason": "Using legacy compatibility assessment",
            "special_requirements": []
        }
