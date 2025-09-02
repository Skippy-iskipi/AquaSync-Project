"""
Fish Compatibility Logic Module

This module contains the pure compatibility checking logic extracted from main.py
without any ML/PyTorch dependencies. Used by the compatibility matrix generator.
"""

from typing import List, Dict, Tuple, Optional, Any
import logging

logger = logging.getLogger(__name__)

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
            return float(parts[0].strip()), float(parts[1].strip())
        return None, None
    except (ValueError, IndexError):
        return None, None

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

def can_same_species_coexist(fish_name: str, fish_info: Dict[str, Any]) -> Tuple[bool, str]:
    """
    Determines if multiple individuals of the same fish species can coexist
    based on temperament, behavior, and species-specific knowledge.
    
    Args:
        fish_name: The common name of the fish
        fish_info: The database record for the fish with all attributes
        
    Returns:
        (bool, str): Tuple of (can_coexist, reason)
    """
    fish_name_lower = fish_name.lower()
    temperament = fish_info.get('temperament', "").lower()
    behavior = fish_info.get('social_behavior', "").lower()
    
    # List of fish that are often aggressive towards their own species
    incompatible_species = [
        "betta", "siamese fighting fish", "paradise fish", 
        "dwarf gourami", "honey gourami", 
        "flowerhorn", "wolf cichlid", "oscar", "jaguar cichlid",
        "rainbow shark", "red tail shark", "pearl gourami",
        "silver arowana", "jardini arowana", "banjar arowana"
    ]
    
    # Check for known incompatible species
    for species in incompatible_species:
        if species in fish_name_lower:
            return False, f"{fish_name} are known to be aggressive/territorial with their own kind."
    
    # Check temperament keywords
    if "aggressive" in temperament or "territorial" in temperament and "community" not in temperament:
        return False, f"{fish_name} have an aggressive or territorial temperament and may fight with each other."
    
    # Check social behavior keywords
    if "solitary" in behavior:
        return False, f"{fish_name} are solitary and prefer to live alone."
    
    return True, f"{fish_name} can generally live together in groups."

def check_pairwise_compatibility(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Tuple[str, List[str], List[str]]:
    """
    Checks if two fish are compatible based on a set of explicit rules.

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

    # Rule 1: Water Type (Critical - always incompatible)
    water1 = str(fish1.get('water_type') or '').lower().strip()
    water2 = str(fish2.get('water_type') or '').lower().strip()
    if water1 and water2 and water1 != water2:
        if 'fresh' in water1 and 'salt' in water2:
            incompatible_reasons.append("Water type mismatch: Freshwater vs Saltwater")
        elif 'salt' in water1 and 'fresh' in water2:
            incompatible_reasons.append("Water type mismatch: Saltwater vs Freshwater")

    # Extract commonly used fields safely
    def _to_float(val) -> Optional[float]:
        try:
            if val is None:
                return None
            return float(val)
        except (ValueError, TypeError):
            return None

    name1 = str(fish1.get('common_name') or '').lower()
    name2 = str(fish2.get('common_name') or '').lower()
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

    # Rule 2: Size Difference (more realistic - allow 3:1 ratio for peaceful fish)
    try:
        if size1 > 0 and size2 > 0:
            size_ratio = max(size1, size2) / min(size1, size2)
            # More restrictive for aggressive fish, more lenient for peaceful fish
            max_ratio = 4.0 if (temp1_score == 0 and temp2_score == 0) else 3.0 if (temp1_score <= 1 and temp2_score <= 1) else 2.0
            if size_ratio >= max_ratio:
                reasons.append("Significant size difference may lead to predation or bullying.")
    except Exception:
        logger.warning("Could not parse size for compatibility check.")

    # Rule 3: Temperament (more realistic - only flag aggressive vs peaceful, not semi-aggressive)
    if temp1_score == 2 and temp2_score == 0:
        reasons.append(f"Temperament conflict: '{temp1_str}' fish cannot be kept with '{temp2_str}' fish.")
    if temp2_score == 2 and temp1_score == 0:
        reasons.append(f"Temperament conflict: '{temp2_str}' fish cannot be kept with '{temp1_str}' fish.")
    # Semi-aggressive (score 1) can often work with peaceful fish in larger tanks - don't auto-reject

    # New Rule 3b: Aggressive vs Aggressive is high-risk
    if temp1_score == 2 and temp2_score == 2:
        reasons.append("Both fish are aggressive; high risk of severe fighting and territorial disputes.")

    # New Rule 3c: Territorial or Solitary behavior (more realistic)
    # Only flag solitary if both fish occupy the same tank level
    tank_level1 = str(fish1.get('tank_level') or '').lower()
    tank_level2 = str(fish2.get('tank_level') or '').lower()
    
    if ("solitary" in behavior1) or ("solitary" in behavior2):
        # Allow solitary bottom dwellers with mid/top level fish
        if ("bottom" in tank_level1 and "bottom" not in tank_level2) or \
           ("bottom" in tank_level2 and "bottom" not in tank_level1):
            pass  # Allow different levels
        else:
            reasons.append("At least one species is solitary and prefers to live alone.")
    if (temp1_str and isinstance(temp1_str, str) and "territorial" in temp1_str.lower()) or \
       (temp2_str and isinstance(temp2_str, str) and "territorial" in temp2_str.lower()):
        # Escalate if both are medium/large
        if (size1 >= 20 and size2 >= 20):
            reasons.append("Territorial species pairing (both medium/large) is likely to lead to conflict.")
        else:
            reasons.append("Territorial behavior increases conflict risk, especially in limited space.")

    # Rule 4: pH Range Overlap
    try:
        ph1_min, ph1_max = parse_range(fish1.get('ph_range'))
        ph2_min, ph2_max = parse_range(fish2.get('ph_range'))
        if ph1_min is not None and ph2_min is not None and (ph1_max < ph2_min or ph2_max < ph1_min):
            reasons.append(f"Incompatible pH requirements: {fish1.get('ph_range')} vs {fish2.get('ph_range')}")
    except (ValueError, TypeError):
        pass

    # Rule 5: Temperature Range Overlap
    try:
        t1_min, t1_max = parse_range(fish1.get('temperature_range_c') or fish1.get('temperature_range_(Â°c)'))
        t2_min, t2_max = parse_range(fish2.get('temperature_range_c') or fish2.get('temperature_range_(Â°c)'))
        if t1_min is not None and t2_min is not None and (t1_max < t2_min or t2_max < t1_min):
            reasons.append(f"Incompatible temperature requirements.")
    except (ValueError, TypeError):
        pass

    # New Rule 6: Predatory species heuristics by name (broad, not just arowanas)
    predator_keywords = [
        "arowana", "oscar", "flowerhorn", "wolf cichlid", "snakehead", "peacock bass",
        "pike cichlid", "payara", "gar", "bichir", "datnoid", "dorado", "piranha",
        "bull shark", "barracuda", "tiger shovelnose", "red tail catfish"
    ]
    is_pred1 = any(k in name1 for k in predator_keywords)
    is_pred2 = any(k in name2 for k in predator_keywords)
    if is_pred1 and is_pred2:
        reasons.append("Both species are large predatory/territorial fish; cohabitation is generally unsafe.")

    # New Rule 7: Predation risk using size and temperament (more realistic)
    try:
        if size1 > 0 and size2 > 0:
            ratio = max(size1, size2) / min(size1, size2) if min(size1, size2) > 0 else None
            # More strict thresholds: 3:1 for semi-aggressive, 2:1 for aggressive/predatory
            if ratio and (is_pred1 or is_pred2):
                if ratio >= 2.0:
                    reasons.append("Size imbalance with predatory/territorial temperament increases predation/bullying risk.")
            elif temp1_score >= 2 or temp2_score >= 2:  # Aggressive only
                if ratio >= 2.0:
                    reasons.append("Size imbalance with aggressive temperament increases predation/bullying risk.")
            # For semi-aggressive (score 1), only flag if ratio is very high
            elif temp1_score >= 1 or temp2_score >= 1:
                if ratio >= 3.5:
                    reasons.append("Large size imbalance with semi-aggressive fish may cause stress.")
    except Exception:
        pass

    # New Rule 7b: Diet-based risks (using 'diet' and 'preferred_food')
    def _diet_category(diet: str, pref: str) -> str:
        s = f"{diet} {pref}".lower()
        if any(k in s for k in ["piscivore", "feeds on fish", "fish-based", "fish prey"]):
            return "piscivore"
        # Omnivore should be checked before carnivore to prevent false categorization
        if "omniv" in s:
            return "omnivore"
        if "carniv" in s or any(k in s for k in ["meat", "predator"]):
            return "carnivore"
        # "live food" alone (without carnivore indicators) is less aggressive
        if "live food" in s:
            return "omnivore"  # Most aquarium fish with live food are omnivores
        if "herbiv" in s or any(k in s for k in ["algae", "vegetable", "plant"]):
            return "herbivore"
        if any(k in s for k in ["plankt", "zooplank"]):
            return "planktivore"
        if any(k in s for k in ["insect", "invertebr", "worm"]):
            return "invertivore"
        return "unknown"

    diet1_raw = str(fish1.get('diet') or '').lower()
    pref1_raw = str(fish1.get('preferred_food') or '').lower()
    diet2_raw = str(fish2.get('diet') or '').lower()
    pref2_raw = str(fish2.get('preferred_food') or '').lower()
    cat1 = _diet_category(diet1_raw, pref1_raw)
    cat2 = _diet_category(diet2_raw, pref2_raw)

    # Carnivore/piscivore with smaller tankmates
    try:
        if size1 > 0 and size2 > 0:
            if cat1 in ("piscivore", "carnivore") and size1 >= size2 * 1.3:
                reasons.append("Carnivorous/piscivorous diet with a much smaller tankmate increases predation risk.")
            if cat2 in ("piscivore", "carnivore") and size2 >= size1 * 1.3:
                reasons.append("Carnivorous/piscivorous diet with a much smaller tankmate increases predation risk.")
    except Exception:
        pass

    # Both carnivorous/piscivorous and medium/large size → feeding aggression
    if (cat1 in ("piscivore", "carnivore")) and (cat2 in ("piscivore", "carnivore")) and (size1 >= 20 and size2 >= 20):
        reasons.append("Both species are carnivorous/piscivorous and medium/large; high competition and aggression during feeding.")

    # Herbivore with large carnivore/piscivore
    if (cat1 == "herbivore" and cat2 in ("piscivore", "carnivore") and size2 >= 20) or \
       (cat2 == "herbivore" and cat1 in ("piscivore", "carnivore") and size1 >= 20):
        reasons.append("Herbivore paired with a large carnivore/piscivore is at risk of harassment or predation.")

    # New Rule 8: Large aggressive/territorial combo
    if (size1 >= 30 and size2 >= 30) and (temp1_score >= 1 and temp2_score >= 1):
        reasons.append("Both species are large and non-peaceful; high likelihood of severe aggression in shared tanks.")

    # New Rule 9: Extremely large minimum tank requirements suggest incompatibility without exceptionally large systems
    try:
        if (min_tank1 and min_tank2) and (min_tank1 >= 300 or min_tank2 >= 300):
            reasons.append("One or both species require very large tanks; mixing species further increases risk in typical setups.")
    except Exception:
        pass

    return not reasons, reasons
