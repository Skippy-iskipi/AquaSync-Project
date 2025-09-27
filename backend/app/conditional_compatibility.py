#!/usr/bin/env python3
"""
Enhanced Conditional Compatibility Logic for AquaSync

This module provides three-tier compatibility checking:
- compatible: Fish can be kept together easily
- conditional: Fish can work together with specific conditions
- incompatible: Fish should not be kept together
"""

from typing import List, Dict, Tuple, Optional, Any
import logging

logger = logging.getLogger(__name__)

def get_temperament_score(temperament_str: Optional[str]) -> int:
    """Converts a temperament string to a numerical score for comparison."""
    if not temperament_str:
        return 0  # Default to peaceful
    temperament_lower = temperament_str.lower()
    if "semi-aggressive" in temperament_lower:
        return 1
    if "aggressive" in temperament_lower:
        return 2
    if "peaceful" in temperament_lower or "community" in temperament_lower:
        return 0
    if "territorial" in temperament_lower and "peaceful" not in temperament_lower:
        return 1
    return 0

def parse_range(range_str: Optional[str]) -> Tuple[Optional[float], Optional[float]]:
    """Parse a range string (e.g., '6.5-7.5' or '22-28') into min and max values."""
    if not range_str:
        return None, None
    try:
        # Remove any non-numeric characters except dash and dot
        range_str = (
            str(range_str)
            .replace('Â°C', '')
            .replace('C', '')
            .replace('c', '')
            .replace('pH', '')
            .replace('PH', '')
            .strip()
        )
        parts = range_str.split('-')
        if len(parts) == 2:
            return float(parts[0]), float(parts[1])
        elif len(parts) == 1:
            val = float(parts[0])
            return val, val
        return None, None
    except (ValueError, TypeError):
        return None, None

def check_conditional_compatibility(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Tuple[str, List[str], List[str]]:
    """
    Enhanced compatibility checking with conditional support.

    Args:
        fish1: A dictionary containing the details of the first fish.
        fish2: A dictionary containing the details of the second fish.

    Returns:
        A tuple with:
        - str: Compatibility level ('compatible', 'conditional', 'incompatible').
        - List[str]: A list of reasons for incompatibility or issues.
        - List[str]: A list of conditions required if compatibility level is 'conditional'.
    """
    incompatible_reasons = []  # Critical issues that make them incompatible
    conditional_reasons = []   # Issues that can be managed with proper conditions
    conditions = []           # Specific conditions required for conditional compatibility

    # Helper function
    def _to_float(val) -> Optional[float]:
        try:
            if val is None:
                return None
            return float(val)
        except (ValueError, TypeError):
            return None

    name1 = str(fish1.get('common_name') or '').lower()
    name2 = str(fish2.get('common_name') or '').lower()
    
    # Rule 0: Same-species compatibility (intra-species interactions)
    if name1 == name2:
        # Betta same-species rules
        if "betta" in name1 or "siamese fighting fish" in name1:
            # Check if it's male vs male (most common case)
            # For now, assume same-species bettas are incompatible unless specified otherwise
            incompatible_reasons.append("Same-species Betta fish are generally incompatible")
            incompatible_reasons.append("Male bettas will fight to the death if housed together")
            incompatible_reasons.append("Female bettas require sorority setup (4-6 females, large planted tank)")
            incompatible_reasons.append("Male and female should only be together for breeding under supervision")
            return "incompatible", incompatible_reasons, []
        
        # Other territorial fish same-species rules
        territorial_fish = ["oscar", "jack dempsey", "green terror", "texas cichlid", "flowerhorn", 
                           "red devil", "midas cichlid", "jaguar cichlid", "wolf cichlid"]
        if any(fish in name1 for fish in territorial_fish):
            incompatible_reasons.append("Same-species territorial fish are incompatible")
            incompatible_reasons.append("These fish are highly territorial and will fight for dominance")
            return "incompatible", incompatible_reasons, []
        
        # Schooling fish same-species rules (generally compatible)
        schooling_fish = ["tetra", "danio", "rasbora", "barb", "corydoras", "pleco", "loach"]
        if any(fish in name1 for fish in schooling_fish):
            conditional_reasons.append("Same-species schooling fish can be kept together")
            conditions.append("Keep in groups of 6+ individuals")
            conditions.append("Provide adequate swimming space")
            conditions.append("Monitor for any aggressive individuals")
            return "conditional", conditional_reasons, conditions
        
        # Default same-species rule
        conditional_reasons.append("Same-species fish compatibility depends on specific species")
        conditions.append("Research specific requirements for this species")
        conditions.append("Consider tank size and individual temperament")
        return "conditional", conditional_reasons, conditions
    
    # Rule 1: Handle special case fish with nuanced compatibility requirements
    
    # Public aquarium only fish - truly incompatible
    public_aquarium_only = [
        "hammerhead shark", "great white", "tiger shark", "whale shark",
        "manta ray", "stingray", "barracuda", "moray eel"
    ]
    
    # Common incompatible combinations - be more strict
    incompatible_combinations = [
        # Aggressive cichlids with peaceful fish
        (["oscar", "jack dempsey", "green terror", "texas cichlid"], ["neon tetra", "guppy", "platy", "molly", "swordtail"]),
        # Large predatory fish with small fish
        (["pike cichlid", "wolf cichlid", "jaguar cichlid"], ["cardinal tetra", "ember tetra", "cherry barb"]),
        # Fin nippers with long-finned fish
        (["tiger barb", "serpae tetra", "black skirt tetra"], ["betta", "angelfish", "gourami"]),
        # Different water types
        (["goldfish", "koi"], ["tropical fish", "tetra", "cichlid"]),
        # Betta specific incompatibilities
        (["betta", "siamese fighting fish"], ["angelfish", "gourami", "paradise fish", "cichlid"]),
        # Angelfish specific incompatibilities
        (["angelfish"], ["betta", "gourami", "paradise fish"]),
    ]
    
    # Check for known incompatible combinations
    for aggressive_group, peaceful_group in incompatible_combinations:
        fish1_in_aggressive = any(aggressive in name1 for aggressive in aggressive_group)
        fish2_in_peaceful = any(peaceful in name2 for peaceful in peaceful_group)
        fish1_in_peaceful = any(peaceful in name1 for peaceful in peaceful_group)
        fish2_in_aggressive = any(aggressive in name2 for aggressive in aggressive_group)
        
        if (fish1_in_aggressive and fish2_in_peaceful) or (fish1_in_peaceful and fish2_in_aggressive):
            incompatible_reasons.append(f"These fish have conflicting temperaments - one is aggressive while the other is peaceful, which will likely result in stress and injury")
            break
    
    is_public_only_1 = any(name in name1 for name in public_aquarium_only)
    is_public_only_2 = any(name in name2 for name in public_aquarium_only)
    
    if is_public_only_1 or is_public_only_2:
        if name1 != name2:  # Different species
            incompatible_reasons.append("This fish is designed for large public aquariums and requires specialized care that's not suitable for home tanks")
    
    # Extremely limited compatibility fish - only with other large aggressive fish
    extremely_limited = [
        "wolf cichlid", "jaguar cichlid", "red devil", "midas cichlid"
    ]
    
    is_extremely_limited_1 = any(name in name1 for name in extremely_limited)
    is_extremely_limited_2 = any(name in name2 for name in extremely_limited)
    
    # Special handling for fish with limited but possible compatibility
    
    # Betta compatibility - can work with specific peaceful fish
    if "betta" in name1 or "betta" in name2:
        if name1 != name2:  # Different species
            # Check if the other fish is betta-compatible
            other_fish = name2 if "betta" in name1 else name1
            other_fish_data = fish2 if "betta" in name1 else fish1
            
            # Betta-incompatible species (aggressive, territorial, or fin-nippers)
            betta_incompatible = [
                "angelfish", "gourami", "paradise fish", "cichlid", "oscar", 
                "jack dempsey", "tiger barb", "serpae tetra", "black skirt tetra"
            ]
            
            # Check for incompatible species first
            is_incompatible_species = any(incompatible in other_fish for incompatible in betta_incompatible)
            if is_incompatible_species:
                incompatible_reasons.append(f"Bettas cannot live with {other_fish} because they are territorial fish that will stress or injure your betta")
            else:
                # Betta-compatible species (peaceful bottom dwellers, small peaceful fish)
                betta_compatible = [
                    "corydoras", "cory", "kuhli loach", "neon tetra", "ember tetra",
                    "harlequin rasbora", "celestial pearl danio", "otocinclus",
                    "mystery snail", "nerite snail", "cherry shrimp"
                ]
                
                temperament = str(other_fish_data.get('temperament', '')).lower()
                is_peaceful = "peaceful" in temperament
                is_compatible_species = any(compatible in other_fish for compatible in betta_compatible)
                
                if is_peaceful and is_compatible_species:
                    conditional_reasons.append(f"Your betta can live with {other_fish}, but you'll need to create the right environment")
                    conditions.append("Use a tank that's at least 20 gallons - smaller tanks increase aggression")
                    conditions.append("Watch your fish closely for the first few weeks and be ready to separate them if needed")
                    conditions.append("Only add very calm fish that won't nip at your betta's beautiful fins")
                else:
                    incompatible_reasons.append(f"Bettas need very specific tankmates - {other_fish} is not suitable for your betta's peaceful nature")
    
    # Angelfish compatibility - semi-aggressive, can be territorial
    elif "angelfish" in name1 or "angelfish" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "angelfish" in name1 else name1
            other_fish_data = fish2 if "angelfish" in name1 else fish1
            
            # Angelfish-incompatible species
            angelfish_incompatible = [
                "betta", "gourami", "paradise fish", "tiger barb", "serpae tetra", 
                "black skirt tetra", "fin nipper"
            ]
            
            # Check for incompatible species
            is_incompatible_species = any(incompatible in other_fish for incompatible in angelfish_incompatible)
            if is_incompatible_species:
                incompatible_reasons.append(f"Angelfish cannot live with {other_fish} because they will damage your angelfish's long fins or fight over territory")
            else:
                # Angelfish-compatible species
                angelfish_compatible = [
                    "corydoras", "cory", "kuhli loach", "neon tetra", "cardinal tetra",
                    "harlequin rasbora", "celestial pearl danio", "otocinclus",
                    "pleco", "bristlenose pleco", "mystery snail", "nerite snail"
                ]
                
                temperament = str(other_fish_data.get('temperament', '')).lower()
                is_peaceful = "peaceful" in temperament
                is_compatible_species = any(compatible in other_fish for compatible in angelfish_compatible)
                
                if is_peaceful and is_compatible_species:
                    conditional_reasons.append(f"Angelfish can live with {other_fish} if you set up their tank properly")
                    conditions.append("Provide a spacious tank (30+ gallons) with tall plants where your angelfish can feel secure")
                    conditions.append("Choose only gentle fish that won't harm your angelfish's delicate fins")
                    conditions.append("Watch for any territorial behavior and be ready to rearrange decorations if needed")
                else:
                    incompatible_reasons.append(f"Angelfish need calm tankmates - {other_fish} is too aggressive for your angelfish")
    
    # Flowerhorn compatibility - only with other large aggressive cichlids
    elif "flowerhorn" in name1 or "flowerhorn" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "flowerhorn" in name1 else name1
            other_fish_data = fish2 if "flowerhorn" in name1 else fish1
            
            # Flowerhorn-compatible species (large aggressive cichlids)
            flowerhorn_compatible = [
                "oscar", "jack dempsey", "texas cichlid", "green terror",
                "electric blue jack dempsey", "pleco", "common pleco"
            ]
            
            temperament = str(other_fish_data.get('temperament', '')).lower()
            is_large_aggressive = any(compatible in other_fish for compatible in flowerhorn_compatible)
            size = float(other_fish_data.get('max_size_(cm)', 0) or 0)
            
            if is_large_aggressive and size > 15:  # Large fish
                conditional_reasons.append(f"Flowerhorn can potentially live with {other_fish}, but this is very risky")
                conditions.append("You'll need an extremely large tank (75+ gallons per fish) to reduce fighting")
                conditions.append("Even with proper setup, these fish may still fight - be prepared for this")
                conditions.append("Watch your fish constantly and have a backup plan to separate them")
                conditions.append("Consider that Flowerhorn often do better when kept alone")
            else:
                incompatible_reasons.append(f"Flowerhorn are extremely aggressive and can only live with other large, tough fish - {other_fish} won't survive")
    
    # Dottyback compatibility - with other semi-aggressive marine fish
    elif "dottyback" in name1 or "dottyback" in name2:
        if name1 != name2:  # Different species
            other_fish = name2 if "dottyback" in name1 else name1
            other_fish_data = fish2 if "dottyback" in name1 else fish1
            
            # Check water type compatibility first
            water1 = str(fish1.get('water_type', '')).lower()
            water2 = str(fish2.get('water_type', '')).lower()
            
            if "saltwater" in water1 and "saltwater" in water2:
                # Marine fish - check temperament compatibility
                dottyback_compatible = [
                    "damselfish", "clownfish", "wrasse", "pseudochromis", "goby",
                    "cardinalfish", "anthias", "tang", "royal gramma"
                ]
                
                temperament = str(other_fish_data.get('temperament', '')).lower()
                is_marine_compatible = any(compatible in other_fish for compatible in dottyback_compatible)
                is_semi_aggressive = "semi" in temperament or "aggressive" in temperament
                
                if is_marine_compatible and (is_semi_aggressive or "peaceful" in temperament):
                    conditional_reasons.append(f"Dottyback can live with {other_fish} in a proper saltwater setup")
                    conditions.append("Use a saltwater tank that's at least 30 gallons to give them enough space")
                    conditions.append("Dottyback can be territorial, so arrange plenty of hiding spots and territories")
                    conditions.append("Don't mix them with very shy fish or large predators")
                else:
                    incompatible_reasons.append(f"Dottyback have strong personalities that clash with {other_fish}")
            else:
                incompatible_reasons.append("Dottyback are saltwater fish and cannot live with freshwater fish - their needs are completely different")
    
    # Original extremely limited compatibility check for remaining fish
    elif is_extremely_limited_1 or is_extremely_limited_2:
        if name1 != name2:  # Different species
            # Only compatible with other large aggressive cichlids
            cichlid1 = "cichlid" in name1 or any(name in name1 for name in ["oscar", "jack dempsey", "green terror"])
            cichlid2 = "cichlid" in name2 or any(name in name2 for name in ["oscar", "jack dempsey", "green terror"])
            
            if cichlid1 and cichlid2:
                conditional_reasons.append("These are very aggressive fish that can potentially live together, but it's extremely challenging")
                conditions.append("You'll need a massive tank (100+ gallons) to give them enough space to avoid constant fighting")
                conditions.append("Expect frequent aggression - these fish are natural fighters")
                conditions.append("This setup is only recommended for very experienced fish keepers")
            else:
                incompatible_reasons.append("These fish are extremely aggressive and will likely kill or severely injure other fish")
    size1 = _to_float(fish1.get('max_size_(cm)')) or 0.0
    size2 = _to_float(fish2.get('max_size_(cm)')) or 0.0
    min_tank1 = (
        _to_float(fish1.get('minimum_tank_size_l'))
        or _to_float(fish1.get('minimum_tank_size_(l)'))
        or _to_float(fish1.get('minimum_tank_size'))
    )
    min_tank2 = (
        _to_float(fish2.get('minimum_tank_size_l'))
        or _to_float(fish2.get('minimum_tank_size_(l)'))
        or _to_float(fish2.get('minimum_tank_size'))
    )

    temp1_str = fish1.get('temperament')
    temp2_str = fish2.get('temperament')
    temp1_score = get_temperament_score(temp1_str)
    temp2_score = get_temperament_score(temp2_str)
    behavior1 = str(fish1.get('social_behavior') or '').lower()
    behavior2 = str(fish2.get('social_behavior') or '').lower()

    # Rule 2: Water Type (Critical - always incompatible)
    water1 = str(fish1.get('water_type') or '').lower().strip()
    water2 = str(fish2.get('water_type') or '').lower().strip()
    if water1 and water2 and water1 != water2:
        if 'fresh' in water1 and 'salt' in water2:
            incompatible_reasons.append("These fish cannot live together because one needs freshwater and the other needs saltwater - their bodies are adapted to completely different environments")
        elif 'salt' in water1 and 'fresh' in water2:
            incompatible_reasons.append("These fish cannot live together because one needs saltwater and the other needs freshwater - their bodies are adapted to completely different environments")

    # Rule 3: Size Difference (Conditional based on temperament)
    try:
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            larger_fish = fish1['common_name'] if size1 > size2 else fish2['common_name']
            smaller_fish = fish2['common_name'] if size1 > size2 else fish1['common_name']
            
            # Critical size difference (5:1 or more)
            if size_ratio >= 5.0:
                incompatible_reasons.append(f"One fish is {size_ratio:.1f} times larger than the other - the larger fish will likely eat or seriously injure the smaller one")
            # Conditional size difference
            elif size_ratio >= 3.0 and (temp1_score >= 1 or temp2_score >= 1):
                conditional_reasons.append(f"There's a significant size difference ({size_ratio:.1f}:1) and one fish is semi-aggressive, which increases the risk")
                conditions.append("Use a very large tank (200+ liters) with lots of hiding places for the smaller fish")
                conditions.append("Watch carefully during feeding time when aggression is most likely to occur")
            elif size_ratio >= 4.0 and (temp1_score == 0 and temp2_score == 0):
                conditional_reasons.append(f"Even though both fish are peaceful, there's a big size difference ({size_ratio:.1f}:1) that could be dangerous")
                conditions.append("Make sure the smaller fish can't accidentally be eaten by the larger one")
                conditions.append("Create plenty of hiding spots where the smaller fish can escape if needed")
    except Exception:
        logger.warning("Could not parse size for compatibility check.")

    # Rule 4: Temperament Compatibility (More Strict)
    if temp1_score == 2 and temp2_score == 0:
        incompatible_reasons.append(f"The aggressive nature of {fish1['common_name']} will stress and likely harm your peaceful {fish2['common_name']}")
    elif temp2_score == 2 and temp1_score == 0:
        incompatible_reasons.append(f"The aggressive nature of {fish2['common_name']} will stress and likely harm your peaceful {fish1['common_name']}")
    elif temp1_score == 2 and temp2_score == 2:
        incompatible_reasons.append("Both fish are very aggressive and will constantly fight, causing stress and injury")
    elif (temp1_score == 2 and temp2_score == 1) or (temp1_score == 1 and temp2_score == 2):
        # Aggressive with semi-aggressive - high risk, usually incompatible
        incompatible_reasons.append("Mixing aggressive and semi-aggressive fish creates a dangerous situation where fighting is almost certain")
    elif (temp1_score == 1 and temp2_score == 0) or (temp2_score == 1 and temp1_score == 0):
        # Semi-aggressive with peaceful - be more strict
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio >= 2.0:  # If there's a significant size difference
                incompatible_reasons.append(f"The semi-aggressive fish is much larger than the peaceful one, creating a dangerous situation where bullying is very likely")
            else:
                conditional_reasons.append("Semi-aggressive fish can stress peaceful fish, but it's manageable with proper setup")
                conditions.append("Use a large tank (150+ liters) with plenty of territories and hiding spots")
                conditions.append("Add the peaceful fish first so they can establish their own territories")
        else:
            # No size data - be conservative
            conditional_reasons.append("Semi-aggressive fish can stress peaceful fish, so you'll need to watch them carefully")
            conditions.append("Use a large tank (150+ liters) with plenty of territories and hiding spots")
            conditions.append("Add the peaceful fish first so they can establish their own territories")

    # Rule 5: Social Behavior Compatibility
    tank_level1 = str(fish1.get('tank_level') or '').lower()
    tank_level2 = str(fish2.get('tank_level') or '').lower()
    
    # Check for solitary behavior
    if ("solitary" in behavior1) or ("solitary" in behavior2):
        # Allow solitary bottom dwellers with mid/top level fish
        if ("bottom" in tank_level1 and "bottom" not in tank_level2) or \
           ("bottom" in tank_level2 and "bottom" not in tank_level1):
            conditional_reasons.append("One fish prefers to be alone but can live with fish that occupy different areas of the tank")
            conditions.append("Create separate territories and caves where the solitary fish can retreat")
        else:
            incompatible_reasons.append("One of these fish prefers to live alone and will be stressed by having tankmates")
    
    # Check for territorial behavior (separate from solitary)
    if ("territorial" in behavior1) or ("territorial" in behavior2):
        # Territorial fish with aggressive temperament are especially problematic
        if (temp1_score >= 2 and "territorial" in behavior1) or (temp2_score >= 2 and "territorial" in behavior2):
            incompatible_reasons.append("These territorial fish are too aggressive and will fight constantly over territory")
        elif (temp1_score >= 1 and "territorial" in behavior1) or (temp2_score >= 1 and "territorial" in behavior2):
            conditional_reasons.append("Territorial fish need careful management to prevent constant fighting")
            conditions.append("Use a very large tank (300+ liters) with multiple distinct territories and visual barriers")
            conditions.append("Add the territorial fish last so they don't claim the entire tank")
            conditions.append("Watch for territorial disputes and be ready to separate if fighting becomes severe")

    # Rule 6: pH Compatibility (Conditional for minor differences)
    try:
        ph1_min, ph1_max = parse_range(fish1.get('ph_range'))
        ph2_min, ph2_max = parse_range(fish2.get('ph_range'))
        if ph1_min is not None and ph2_min is not None:
            # No overlap
            if ph1_max < ph2_min or ph2_max < ph1_min:
                ph_diff = min(abs(ph1_max - ph2_min), abs(ph2_max - ph1_min))
                if ph_diff > 1.0:
                    incompatible_reasons.append(f"These fish need very different water acidity levels - one needs acidic water while the other needs alkaline water, which will stress both fish")
                else:
                    conditional_reasons.append(f"The pH requirements are quite different but might be manageable")
                    conditions.append(f"You'll need to carefully maintain pH between {max(ph1_min, ph2_min):.1f}-{min(ph1_max, ph2_max):.1f}")
    except (ValueError, TypeError):
        pass

    # Rule 7: Temperature Compatibility (Conditional for minor differences)
    try:
        t1_min, t1_max = parse_range(fish1.get('temperature_range') or fish1.get('temperature_range_c'))
        t2_min, t2_max = parse_range(fish2.get('temperature_range') or fish2.get('temperature_range_c'))
        if t1_min is not None and t2_min is not None:
            # No overlap
            if t1_max < t2_min or t2_max < t1_min:
                temp_diff = min(abs(t1_max - t2_min), abs(t2_max - t1_min))
                if temp_diff > 3.0:
                    incompatible_reasons.append(f"These fish need very different water temperatures - one prefers cold water while the other needs warm water, which will stress both fish")
                else:
                    conditional_reasons.append(f"The temperature requirements are different but might work")
                    conditions.append(f"You'll need to carefully maintain temperature between {max(t1_min, t2_min):.0f}-{min(t1_max, t2_max):.0f}°C")
    except (ValueError, TypeError):
        pass

    # Rule 8: Tank Size Requirements (Conditional for large fish)
    try:
        if (min_tank1 and min_tank1 >= 200) or (min_tank2 and min_tank2 >= 200):
            larger_req = max(min_tank1 or 0, min_tank2 or 0)
            conditional_reasons.append("These fish need a very large tank to thrive")
            conditions.append(f"Your tank must be at least {larger_req} liters - smaller tanks will stress your fish")
            if larger_req >= 400:
                conditions.append("Consider investing in a dedicated large aquarium system for these fish")
    except Exception:
        pass

    # Rule 9: Diet-based Considerations
    def _diet_category(diet: str, pref: str) -> str:
        s = f"{diet} {pref}".lower()
        if any(k in s for k in ["piscivore", "feeds on fish", "fish-based", "fish prey"]):
            return "piscivore"
        if "omniv" in s:
            return "omnivore"
        if "carniv" in s or any(k in s for k in ["meat", "predator"]):
            return "carnivore"
        if "live food" in s:
            return "omnivore"
        return "unknown"

    diet1_raw = str(fish1.get('diet') or '').lower()
    pref1_raw = str(fish1.get('preferred_food') or '').lower()
    diet2_raw = str(fish2.get('diet') or '').lower()
    pref2_raw = str(fish2.get('preferred_food') or '').lower()
    cat1 = _diet_category(diet1_raw, pref1_raw)
    cat2 = _diet_category(diet2_raw, pref2_raw)

    # Piscivorous fish with smaller fish
    try:
        if size1 > 0 and size2 > 0:
            if cat1 == "piscivore" and size1 >= size2 * 2.0:
                incompatible_reasons.append("One fish is a predator that eats other fish, and the other fish is small enough to be eaten")
            elif cat2 == "piscivore" and size2 >= size1 * 2.0:
                incompatible_reasons.append("One fish is a predator that eats other fish, and the other fish is small enough to be eaten")
            elif (cat1 == "carnivore" and size1 >= size2 * 3.0) or (cat2 == "carnivore" and size2 >= size1 * 3.0):
                conditional_reasons.append("One fish is much larger and carnivorous, which could be dangerous for the smaller fish")
                conditions.append("Make sure to feed the carnivorous fish well so it doesn't hunt the smaller fish")
                conditions.append("Create plenty of hiding spots where the smaller fish can escape")
    except Exception:
        pass

    # Determine final compatibility level
    if incompatible_reasons:
        return "incompatible", incompatible_reasons, []
    elif conditional_reasons:
        return "conditional", conditional_reasons, conditions
    else:
        # Check if we have sufficient data to declare compatibility
        has_temperament_data = bool(fish1.get('temperament') and fish2.get('temperament'))
        has_water_data = bool(fish1.get('water_type') and fish2.get('water_type'))
        has_size_data = bool(fish1.get('max_size_(cm)') and fish2.get('max_size_(cm)'))
        
        # If we don't have enough data, be conservative
        if not has_temperament_data or not has_water_data or not has_size_data:
            missing_data = []
            if not has_temperament_data:
                missing_data.append("temperament")
            if not has_water_data:
                missing_data.append("water type")
            if not has_size_data:
                missing_data.append("size information")
            
            conditional_reasons.append(f"We don't have enough information about these fish to give you a complete compatibility assessment (missing: {', '.join(missing_data)})")
            conditions.append("Watch your fish very carefully when you first introduce them to each other")
            conditions.append("Be ready to separate them immediately if you see any signs of fighting or stress")
            conditions.append("Consider talking to experienced aquarium keepers or fish store staff for advice")
            return "conditional", conditional_reasons, conditions
        # Generate detailed compatibility reasons for compatible fish
        compatible_reasons = []
        
        # Water parameter compatibility
        if t1_min and t1_max and t2_min and t2_max:
            temp_overlap = min(t1_max, t2_max) - max(t1_min, t2_min)
            if temp_overlap > 0:
                compatible_reasons.append(f"Great news! Both fish are comfortable in the same temperature range ({max(t1_min, t2_min):.0f}-{min(t1_max, t2_max):.0f}°C)")
        
        # pH compatibility
        if ph1_min and ph1_max and ph2_min and ph2_max:
            ph_overlap = min(ph1_max, ph2_max) - max(ph1_min, ph2_min)
            if ph_overlap > 0:
                compatible_reasons.append(f"Both fish like similar water acidity levels (pH {max(ph1_min, ph2_min):.1f}-{min(ph1_max, ph2_max):.1f})")
        
        # Temperament compatibility
        temp1_str = str(fish1.get('temperament', '')).lower()
        temp2_str = str(fish2.get('temperament', '')).lower()
        if temp1_str and temp2_str:
            if 'peaceful' in temp1_str and 'peaceful' in temp2_str:
                compatible_reasons.append("Both fish are peaceful and gentle, making them perfect tankmates")
            elif 'community' in temp1_str or 'community' in temp2_str:
                compatible_reasons.append("These fish are known for being friendly and getting along well with other fish")
        
        # Size compatibility
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio < 2.0:
                compatible_reasons.append(f"Both fish are similar in size, which reduces the risk of bullying or accidental injuries")
        
        # Diet compatibility
        if cat1 and cat2 and cat1 != "unknown" and cat2 != "unknown":
            if cat1 == cat2:
                compatible_reasons.append(f"Both fish eat the same type of food ({cat1}), making feeding easier")
            elif cat1 in ["herbivore", "omnivore"] and cat2 in ["herbivore", "omnivore"]:
                compatible_reasons.append("Both fish enjoy plant-based foods, so you can feed them similar diets")
        
        # Social behavior compatibility
        social1 = str(fish1.get('social_behavior', '')).lower()
        social2 = str(fish2.get('social_behavior', '')).lower()
        if social1 and social2:
            if 'school' in social1 and 'school' in social2:
                compatible_reasons.append("Both fish enjoy being in groups, so they'll be happy together")
            elif 'peaceful' in social1 or 'peaceful' in social2:
                compatible_reasons.append("These fish have calm personalities that work well together")
        
        # Fallback if no specific reasons found
        if not compatible_reasons:
            compatible_reasons.append("These fish should get along well based on their water needs, temperament, size, and behavior")
        
        return "compatible", compatible_reasons, []

# Wrapper function for backward compatibility
def check_pairwise_compatibility(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """Backward compatibility wrapper that returns boolean compatibility."""
    compatibility_level, reasons, conditions = check_conditional_compatibility(fish1, fish2)
    is_compatible = compatibility_level in ["compatible", "conditional"]
    all_reasons = reasons + (conditions if compatibility_level == "conditional" else [])
    return is_compatible, all_reasons
