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
            incompatible_reasons.append(f"Known incompatible combination: aggressive fish with peaceful fish")
            break
    
    is_public_only_1 = any(name in name1 for name in public_aquarium_only)
    is_public_only_2 = any(name in name2 for name in public_aquarium_only)
    
    if is_public_only_1 or is_public_only_2:
        if name1 != name2:  # Different species
            incompatible_reasons.append("Public aquarium species - not suitable for home aquarium community tanks")
    
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
                incompatible_reasons.append(f"Betta is not compatible with {other_fish} - {other_fish} is aggressive/territorial or may nip fins")
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
                    conditional_reasons.append(f"Betta can be housed with {other_fish} with careful monitoring")
                    conditions.append("Requires 20+ gallon tank for community setup")
                    conditions.append("Monitor for aggression and be prepared to separate")
                    conditions.append("Ensure peaceful, non-fin-nipping tankmates only")
                else:
                    incompatible_reasons.append(f"Betta is not compatible with {other_fish} - requires very specific peaceful tankmates")
    
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
                incompatible_reasons.append(f"Angelfish is not compatible with {other_fish} - {other_fish} may nip fins or cause territorial conflicts")
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
                    conditional_reasons.append(f"Angelfish can be housed with {other_fish} with proper tank setup")
                    conditions.append("Requires 30+ gallon tank with tall plants and hiding spots")
                    conditions.append("Avoid fin-nipping species")
                    conditions.append("Monitor for territorial behavior")
                else:
                    incompatible_reasons.append(f"Angelfish is not compatible with {other_fish} - requires peaceful, non-fin-nipping tankmates")
    
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
                conditional_reasons.append(f"Flowerhorn may be housed with {other_fish} in very large tanks")
                conditions.append("Requires 75+ gallon tank per fish")
                conditions.append("Fighting is common even with 'compatible' fish")
                conditions.append("Monitor closely and be prepared to separate")
                conditions.append("Often best kept alone")
            else:
                incompatible_reasons.append(f"Flowerhorn is not compatible with {other_fish} - requires other large aggressive cichlids only")
    
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
                    conditional_reasons.append(f"Dottyback can be housed with {other_fish} in marine setup")
                    conditions.append("Requires 30+ gallon marine tank")
                    conditions.append("Territorial but manageable with proper tank setup")
                    conditions.append("Avoid very timid or very large predatory fish")
                else:
                    incompatible_reasons.append(f"Dottyback temperament not compatible with {other_fish}")
            else:
                incompatible_reasons.append("Dottyback requires saltwater - not compatible with freshwater fish")
    
    # Original extremely limited compatibility check for remaining fish
    elif is_extremely_limited_1 or is_extremely_limited_2:
        if name1 != name2:  # Different species
            # Only compatible with other large aggressive cichlids
            cichlid1 = "cichlid" in name1 or any(name in name1 for name in ["oscar", "jack dempsey", "green terror"])
            cichlid2 = "cichlid" in name2 or any(name in name2 for name in ["oscar", "jack dempsey", "green terror"])
            
            if cichlid1 and cichlid2:
                conditional_reasons.append("Large aggressive cichlids - may be compatible in very large tanks")
                conditions.append("Requires 100+ gallon tank")
                conditions.append("High risk of aggression - monitor closely")
                conditions.append("Only for experienced aquarists")
            else:
                incompatible_reasons.append("Extremely aggressive fish - only compatible with other large aggressive cichlids")
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
            incompatible_reasons.append("Water type mismatch: Freshwater vs Saltwater")
        elif 'salt' in water1 and 'fresh' in water2:
            incompatible_reasons.append("Water type mismatch: Saltwater vs Freshwater")

    # Rule 3: Size Difference (Conditional based on temperament)
    try:
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            larger_fish = fish1['common_name'] if size1 > size2 else fish2['common_name']
            smaller_fish = fish2['common_name'] if size1 > size2 else fish1['common_name']
            
            # Critical size difference (5:1 or more)
            if size_ratio >= 5.0:
                incompatible_reasons.append(f"Extreme size difference ({size_ratio:.1f}:1) - high predation risk")
            # Conditional size difference
            elif size_ratio >= 3.0 and (temp1_score >= 1 or temp2_score >= 1):
                conditional_reasons.append(f"Size difference ({size_ratio:.1f}:1) with semi-aggressive temperament")
                conditions.append("Large tank (200L+) with plenty of hiding spots")
                conditions.append("Monitor for aggression during feeding")
            elif size_ratio >= 4.0 and (temp1_score == 0 and temp2_score == 0):
                conditional_reasons.append(f"Large size difference ({size_ratio:.1f}:1) between peaceful fish")
                conditions.append("Ensure smaller fish can't fit in larger fish's mouth")
                conditions.append("Provide hiding spots for smaller fish")
    except Exception:
        logger.warning("Could not parse size for compatibility check.")

    # Rule 4: Temperament Compatibility (More Strict)
    if temp1_score == 2 and temp2_score == 0:
        incompatible_reasons.append(f"Temperament conflict: '{temp1_str}' fish cannot be kept with '{temp2_str}' fish")
    elif temp2_score == 2 and temp1_score == 0:
        incompatible_reasons.append(f"Temperament conflict: '{temp2_str}' fish cannot be kept with '{temp1_str}' fish")
    elif temp1_score == 2 and temp2_score == 2:
        incompatible_reasons.append("Both fish are aggressive; high risk of severe fighting")
    elif (temp1_score == 2 and temp2_score == 1) or (temp1_score == 1 and temp2_score == 2):
        # Aggressive with semi-aggressive - high risk, usually incompatible
        incompatible_reasons.append("Aggressive fish with semi-aggressive fish creates high risk of fighting and stress")
    elif (temp1_score == 1 and temp2_score == 0) or (temp2_score == 1 and temp1_score == 0):
        # Semi-aggressive with peaceful - be more strict
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio >= 2.0:  # If there's a significant size difference
                incompatible_reasons.append(f"Semi-aggressive fish with peaceful fish and significant size difference ({size_ratio:.1f}:1) - high risk")
            else:
                conditional_reasons.append("Semi-aggressive fish with peaceful fish may cause stress")
                conditions.append("Large tank (150L+) with territories and hiding spots")
                conditions.append("Introduce peaceful fish first to establish territory")
        else:
            # No size data - be conservative
            conditional_reasons.append("Semi-aggressive fish with peaceful fish - monitor closely")
            conditions.append("Large tank (150L+) with territories and hiding spots")
            conditions.append("Introduce peaceful fish first to establish territory")

    # Rule 5: Social Behavior Compatibility
    tank_level1 = str(fish1.get('tank_level') or '').lower()
    tank_level2 = str(fish2.get('tank_level') or '').lower()
    
    # Check for solitary behavior
    if ("solitary" in behavior1) or ("solitary" in behavior2):
        # Allow solitary bottom dwellers with mid/top level fish
        if ("bottom" in tank_level1 and "bottom" not in tank_level2) or \
           ("bottom" in tank_level2 and "bottom" not in tank_level1):
            conditional_reasons.append("Solitary fish with different tank level fish")
            conditions.append("Provide separate territories/caves for solitary fish")
        else:
            incompatible_reasons.append("At least one species is solitary and prefers to live alone")
    
    # Check for territorial behavior (separate from solitary)
    if ("territorial" in behavior1) or ("territorial" in behavior2):
        # Territorial fish with aggressive temperament are especially problematic
        if (temp1_score >= 2 and "territorial" in behavior1) or (temp2_score >= 2 and "territorial" in behavior2):
            incompatible_reasons.append("Territorial aggressive fish are incompatible with most tankmates")
        elif (temp1_score >= 1 and "territorial" in behavior1) or (temp2_score >= 1 and "territorial" in behavior2):
            conditional_reasons.append("Territorial fish require careful tank management")
            conditions.append("Very large tank (300L+) with multiple territories and sight breaks")
            conditions.append("Introduce territorial fish last to avoid established territory conflicts")
            conditions.append("Monitor closely for aggression and be prepared to separate")

    # Rule 6: pH Compatibility (Conditional for minor differences)
    try:
        ph1_min, ph1_max = parse_range(fish1.get('ph_range'))
        ph2_min, ph2_max = parse_range(fish2.get('ph_range'))
        if ph1_min is not None and ph2_min is not None:
            # No overlap
            if ph1_max < ph2_min or ph2_max < ph1_min:
                ph_diff = min(abs(ph1_max - ph2_min), abs(ph2_max - ph1_min))
                if ph_diff > 1.0:
                    incompatible_reasons.append(f"Incompatible pH requirements: {fish1.get('ph_range')} vs {fish2.get('ph_range')}")
                else:
                    conditional_reasons.append(f"Narrow pH compatibility window")
                    conditions.append(f"Maintain pH between {max(ph1_min, ph2_min):.1f}-{min(ph1_max, ph2_max):.1f}")
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
                    incompatible_reasons.append(f"Incompatible temperature requirements")
                else:
                    conditional_reasons.append(f"Narrow temperature compatibility window")
                    conditions.append(f"Maintain temperature between {max(t1_min, t2_min):.0f}-{min(t1_max, t2_max):.0f}°C")
    except (ValueError, TypeError):
        pass

    # Rule 8: Tank Size Requirements (Conditional for large fish)
    try:
        if (min_tank1 and min_tank1 >= 200) or (min_tank2 and min_tank2 >= 200):
            larger_req = max(min_tank1 or 0, min_tank2 or 0)
            conditional_reasons.append("Large tank requirements")
            conditions.append(f"Minimum tank size: {larger_req}L")
            if larger_req >= 400:
                conditions.append("Consider dedicated large aquarium system")
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
                incompatible_reasons.append("Piscivorous fish with much smaller tankmate increases predation risk")
            elif cat2 == "piscivore" and size2 >= size1 * 2.0:
                incompatible_reasons.append("Piscivorous fish with much smaller tankmate increases predation risk")
            elif (cat1 == "carnivore" and size1 >= size2 * 3.0) or (cat2 == "carnivore" and size2 >= size1 * 3.0):
                conditional_reasons.append("Carnivorous fish with significantly smaller tankmate")
                conditions.append("Feed carnivorous fish well to reduce hunting behavior")
                conditions.append("Provide hiding spots for smaller fish")
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
            
            conditional_reasons.append(f"Insufficient data for complete compatibility assessment (missing: {', '.join(missing_data)})")
            conditions.append("Monitor fish behavior closely when introducing")
            conditions.append("Be prepared to separate if any aggression occurs")
            conditions.append("Consider consulting with aquarium experts")
            return "conditional", conditional_reasons, conditions
        # Generate detailed compatibility reasons for compatible fish
        compatible_reasons = []
        
        # Water parameter compatibility
        if t1_min and t1_max and t2_min and t2_max:
            temp_overlap = min(t1_max, t2_max) - max(t1_min, t2_min)
            if temp_overlap > 0:
                compatible_reasons.append(f"Compatible temperature ranges: {name1.title()} ({t1_min}-{t1_max}°C) and {name2.title()} ({t2_min}-{t2_max}°C)")
        
        # pH compatibility
        if ph1_min and ph1_max and ph2_min and ph2_max:
            ph_overlap = min(ph1_max, ph2_max) - max(ph1_min, ph2_min)
            if ph_overlap > 0:
                compatible_reasons.append(f"Similar pH preferences: {name1.title()} ({ph1_min}-{ph1_max}) and {name2.title()} ({ph2_min}-{ph2_max})")
        
        # Temperament compatibility
        temp1_str = str(fish1.get('temperament', '')).lower()
        temp2_str = str(fish2.get('temperament', '')).lower()
        if temp1_str and temp2_str:
            if 'peaceful' in temp1_str and 'peaceful' in temp2_str:
                compatible_reasons.append("Both species have peaceful temperaments, making them ideal tankmates")
            elif 'community' in temp1_str or 'community' in temp2_str:
                compatible_reasons.append("Community-friendly species that coexist well with other fish")
        
        # Size compatibility
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            if size_ratio < 2.0:
                compatible_reasons.append(f"Similar sizes reduce aggression risk: {name1.title()} ({size1}cm) and {name2.title()} ({size2}cm)")
        
        # Diet compatibility
        if cat1 and cat2 and cat1 != "unknown" and cat2 != "unknown":
            if cat1 == cat2:
                compatible_reasons.append(f"Both species share similar dietary needs ({cat1})")
            elif cat1 in ["herbivore", "omnivore"] and cat2 in ["herbivore", "omnivore"]:
                compatible_reasons.append("Compatible feeding habits - both accept plant-based foods")
        
        # Social behavior compatibility
        social1 = str(fish1.get('social_behavior', '')).lower()
        social2 = str(fish2.get('social_behavior', '')).lower()
        if social1 and social2:
            if 'school' in social1 and 'school' in social2:
                compatible_reasons.append("Both are schooling species that benefit from group environments")
            elif 'peaceful' in social1 or 'peaceful' in social2:
                compatible_reasons.append("Peaceful social behaviors promote harmonious coexistence")
        
        # Fallback if no specific reasons found
        if not compatible_reasons:
            compatible_reasons.append("Species compatibility confirmed through comprehensive analysis of water parameters, temperament, size, and behavioral traits")
        
        return "compatible", compatible_reasons, []

# Wrapper function for backward compatibility
def check_pairwise_compatibility(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """Backward compatibility wrapper that returns boolean compatibility."""
    compatibility_level, reasons, conditions = check_conditional_compatibility(fish1, fish2)
    is_compatible = compatibility_level in ["compatible", "conditional"]
    all_reasons = reasons + (conditions if compatibility_level == "conditional" else [])
    return is_compatible, all_reasons
