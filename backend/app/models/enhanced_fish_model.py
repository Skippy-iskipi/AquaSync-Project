#!/usr/bin/env python3
"""
Enhanced Fish Data Model for Comprehensive Compatibility Analysis

This model includes all the attributes necessary for accurate fish compatibility checking:
- Water parameters (temperature, pH, hardness)
- Social and behavioral traits
- Physical characteristics
- Tank requirements
- Special considerations
"""

from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from enum import Enum

class WaterType(Enum):
    FRESHWATER = "Freshwater"
    SALTWATER = "Saltwater"
    BRACKISH = "Brackish"

class Temperament(Enum):
    PEACEFUL = "Peaceful"
    SEMI_AGGRESSIVE = "Semi-aggressive"
    AGGRESSIVE = "Aggressive"
    TERRITORIAL = "Territorial"

class SocialBehavior(Enum):
    SCHOOLING = "Schooling"  # Needs group of 6+
    SHOALING = "Shoaling"    # Prefers group of 3-5
    PAIRS = "Pairs"          # Best in pairs
    COMMUNITY = "Community"  # Good with others
    SOLITARY = "Solitary"    # Prefers alone
    TERRITORIAL = "Territorial"  # Needs own territory

class ActivityLevel(Enum):
    LOW = "Low"              # Bottom dwellers, slow moving
    MODERATE = "Moderate"    # Normal activity
    HIGH = "High"            # Very active, fast swimmers
    NOCTURNAL = "Nocturnal"  # Active at night

class TankZone(Enum):
    TOP = "Top"
    MID = "Mid"
    BOTTOM = "Bottom"
    ALL = "All"              # Uses all levels

class Diet(Enum):
    HERBIVORE = "Herbivore"
    CARNIVORE = "Carnivore"
    OMNIVORE = "Omnivore"
    PLANKTIVORE = "Planktivore"
    INSECTIVORE = "Insectivore"
    PISCIVORE = "Piscivore"  # Fish eater

class FinVulnerability(Enum):
    HARDY = "Hardy"          # Tough fins, not easily nipped
    MODERATE = "Moderate"    # Some vulnerability
    VULNERABLE = "Vulnerable" # Long/flowing fins, easily nipped

class BreedingBehavior(Enum):
    EGG_SCATTERER = "Egg scatterer"
    EGG_LAYER = "Egg layer"
    MOUTHBROODER = "Mouthbrooder"
    BUBBLE_NESTER = "Bubble nester"
    LIVE_BEARER = "Live bearer"
    NO_BREEDING = "No breeding"  # Doesn't breed in aquarium

@dataclass
class EnhancedFishData:
    """Comprehensive fish data model for compatibility analysis"""
    
    # Basic identification
    common_name: str
    scientific_name: str = ""
    family: str = ""
    
    # Water parameters
    water_type: WaterType = None
    temperature_min: float = 0.0      # °C
    temperature_max: float = 0.0      # °C
    ph_min: float = 0.0
    ph_max: float = 0.0
    hardness_min: float = 0.0         # dGH (German degrees)
    hardness_max: float = 0.0         # dGH
    
    # Behavioral traits
    temperament: Temperament = None
    social_behavior: SocialBehavior = None
    activity_level: ActivityLevel = None
    
    # Physical characteristics
    max_size_cm: float = 0.0
    min_tank_size_l: float = 0.0
    tank_zone: TankZone = None
    
    # Diet and feeding
    diet: Diet = None
    feeding_frequency: str = ""       # "2-3 times daily", etc.
    
    # Compatibility factors
    fin_vulnerability: FinVulnerability = None
    fin_nipper: bool = False          # Does this fish nip fins?
    breeding_behavior: BreedingBehavior = None
    
    # Special requirements
    reef_safe: Optional[bool] = None  # For saltwater fish
    schooling_min_number: int = 1     # Minimum group size if schooling
    territorial_space_cm: float = 0.0 # Territory diameter needed
    hiding_spots_required: bool = False
    strong_current_needed: bool = False
    special_diet_requirements: str = ""
    
    # Care level
    care_level: str = ""              # Beginner, Intermediate, Expert
    
    # Data quality
    confidence_score: float = 0.0     # 0.0-1.0 based on source reliability
    sources: List[str] = None
    last_updated: str = ""
    
    def __post_init__(self):
        if self.sources is None:
            self.sources = []

# Compatibility checking functions using enhanced attributes

def check_water_parameter_compatibility(fish1: EnhancedFishData, fish2: EnhancedFishData) -> tuple[bool, list[str], list[str]]:
    """Check water parameter compatibility between two fish"""
    incompatible = []
    conditions = []
    
    # Water type must match
    if fish1.water_type != fish2.water_type:
        incompatible.append(f"Water type mismatch: {fish1.water_type.value} vs {fish2.water_type.value}")
        return False, incompatible, conditions
    
    # Temperature range overlap
    temp_overlap = max(fish1.temperature_min, fish2.temperature_min) <= min(fish1.temperature_max, fish2.temperature_max)
    if not temp_overlap:
        incompatible.append(f"No temperature overlap: {fish1.temperature_min}-{fish1.temperature_max}°C vs {fish2.temperature_min}-{fish2.temperature_max}°C")
    elif (min(fish1.temperature_max, fish2.temperature_max) - max(fish1.temperature_min, fish2.temperature_min)) < 2:
        conditions.append("Very narrow temperature range compatibility - monitor carefully")
    
    # pH range overlap
    ph_overlap = max(fish1.ph_min, fish2.ph_min) <= min(fish1.ph_max, fish2.ph_max)
    if not ph_overlap:
        incompatible.append(f"No pH overlap: {fish1.ph_min}-{fish1.ph_max} vs {fish2.ph_min}-{fish2.ph_max}")
    elif (min(fish1.ph_max, fish2.ph_max) - max(fish1.ph_min, fish2.ph_min)) < 0.5:
        conditions.append("Narrow pH compatibility - maintain stable water parameters")
    
    # Hardness compatibility (more flexible)
    if fish1.hardness_min > 0 and fish2.hardness_min > 0:
        hardness_overlap = max(fish1.hardness_min, fish2.hardness_min) <= min(fish1.hardness_max, fish2.hardness_max)
        if not hardness_overlap:
            conditions.append("Different hardness preferences - gradual acclimation needed")
    
    return len(incompatible) == 0, incompatible, conditions

def check_behavioral_compatibility(fish1: EnhancedFishData, fish2: EnhancedFishData) -> tuple[bool, list[str], list[str]]:
    """Check behavioral compatibility between two fish"""
    incompatible = []
    conditions = []
    
    # Temperament compatibility
    temp_scores = {
        Temperament.PEACEFUL: 0,
        Temperament.SEMI_AGGRESSIVE: 1,
        Temperament.AGGRESSIVE: 2,
        Temperament.TERRITORIAL: 2
    }
    
    score1 = temp_scores.get(fish1.temperament, 1)
    score2 = temp_scores.get(fish2.temperament, 1)
    
    if score1 == 2 and score2 == 0:
        incompatible.append(f"Temperament mismatch: {fish1.temperament.value} fish with {fish2.temperament.value} fish")
    elif score2 == 2 and score1 == 0:
        incompatible.append(f"Temperament mismatch: {fish2.temperament.value} fish with {fish1.temperament.value} fish")
    elif score1 == 2 and score2 == 2:
        incompatible.append("Both fish are aggressive/territorial - high conflict risk")
    elif (score1 == 1 and score2 == 0) or (score2 == 1 and score1 == 0):
        conditions.append("Semi-aggressive with peaceful fish - provide hiding spots and monitor")
    
    # Social behavior compatibility
    if fish1.social_behavior == SocialBehavior.SOLITARY or fish2.social_behavior == SocialBehavior.SOLITARY:
        if fish1.tank_zone != fish2.tank_zone:
            conditions.append("Solitary fish with different tank zones - provide separate territories")
        else:
            incompatible.append("Solitary fish sharing same tank zone")
    
    # Activity level compatibility
    if fish1.activity_level == ActivityLevel.HIGH and fish2.activity_level == ActivityLevel.LOW:
        conditions.append("High activity fish may stress slow-moving fish")
    elif fish2.activity_level == ActivityLevel.HIGH and fish1.activity_level == ActivityLevel.LOW:
        conditions.append("High activity fish may stress slow-moving fish")
    
    # Fin nipping concerns
    if fish1.fin_nipper and fish2.fin_vulnerability == FinVulnerability.VULNERABLE:
        incompatible.append(f"{fish1.common_name} may nip {fish2.common_name}'s fins")
    elif fish2.fin_nipper and fish1.fin_vulnerability == FinVulnerability.VULNERABLE:
        incompatible.append(f"{fish2.common_name} may nip {fish1.common_name}'s fins")
    
    return len(incompatible) == 0, incompatible, conditions

def check_physical_compatibility(fish1: EnhancedFishData, fish2: EnhancedFishData) -> tuple[bool, list[str], list[str]]:
    """Check physical size and space compatibility"""
    incompatible = []
    conditions = []
    
    # Size difference
    if fish1.max_size_cm > 0 and fish2.max_size_cm > 0:
        size_ratio = max(fish1.max_size_cm, fish2.max_size_cm) / min(fish1.max_size_cm, fish2.max_size_cm)
        
        # Very large size difference
        if size_ratio >= 5.0:
            incompatible.append(f"Extreme size difference ({size_ratio:.1f}:1) - predation risk")
        elif size_ratio >= 3.0:
            conditions.append(f"Significant size difference ({size_ratio:.1f}:1) - monitor for bullying")
    
    # Tank size requirements
    min_tank_needed = max(fish1.min_tank_size_l, fish2.min_tank_size_l)
    if min_tank_needed >= 400:
        conditions.append(f"Large tank required: minimum {min_tank_needed}L")
    
    # Tank zone competition
    if fish1.tank_zone == fish2.tank_zone and fish1.tank_zone != TankZone.ALL:
        if fish1.temperament in [Temperament.TERRITORIAL, Temperament.AGGRESSIVE] or \
           fish2.temperament in [Temperament.TERRITORIAL, Temperament.AGGRESSIVE]:
            conditions.append(f"Both fish prefer {fish1.tank_zone.value} zone - provide extra space")
    
    return len(incompatible) == 0, incompatible, conditions

def check_dietary_compatibility(fish1: EnhancedFishData, fish2: EnhancedFishData) -> tuple[bool, list[str], list[str]]:
    """Check dietary compatibility and feeding behavior"""
    incompatible = []
    conditions = []
    
    # Piscivore with smaller fish
    if fish1.diet == Diet.PISCIVORE and fish1.max_size_cm >= fish2.max_size_cm * 1.5:
        incompatible.append("Piscivorous fish may eat smaller tankmate")
    elif fish2.diet == Diet.PISCIVORE and fish2.max_size_cm >= fish1.max_size_cm * 1.5:
        incompatible.append("Piscivorous fish may eat smaller tankmate")
    
    # Feeding competition
    if fish1.diet == fish2.diet and fish1.activity_level == ActivityLevel.HIGH and fish2.activity_level == ActivityLevel.LOW:
        conditions.append("Fast feeders may outcompete slow feeders - target feeding needed")
    
    # Special diet requirements
    if fish1.special_diet_requirements and fish2.special_diet_requirements:
        if fish1.special_diet_requirements != fish2.special_diet_requirements:
            conditions.append("Different special diet requirements - separate feeding may be needed")
    
    return len(incompatible) == 0, incompatible, conditions

def check_enhanced_compatibility(fish1: EnhancedFishData, fish2: EnhancedFishData) -> tuple[str, list[str], list[str]]:
    """
    Comprehensive compatibility check using enhanced fish data model
    
    Returns:
        - compatibility_level: 'compatible', 'conditional', 'incompatible'
        - reasons: List of issues/concerns
        - conditions: List of conditions needed for conditional compatibility
    """
    all_incompatible = []
    all_conditions = []
    
    # Check each compatibility aspect
    water_compat, water_incomp, water_cond = check_water_parameter_compatibility(fish1, fish2)
    behavioral_compat, behav_incomp, behav_cond = check_behavioral_compatibility(fish1, fish2)
    physical_compat, phys_incomp, phys_cond = check_physical_compatibility(fish1, fish2)
    dietary_compat, diet_incomp, diet_cond = check_dietary_compatibility(fish1, fish2)
    
    # Combine results
    all_incompatible.extend(water_incomp + behav_incomp + phys_incomp + diet_incomp)
    all_conditions.extend(water_cond + behav_cond + phys_cond + diet_cond)
    
    # Determine overall compatibility
    if all_incompatible:
        return "incompatible", all_incompatible, []
    elif all_conditions:
        return "conditional", all_conditions, all_conditions
    else:
        return "compatible", ["These fish are compatible"], []
