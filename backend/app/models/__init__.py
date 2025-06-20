"""
AquaSync backend package
""" 

from .fish_classifier import LightweightFishClassifier, val_transforms
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class FishSpecies(BaseModel):
    id: Optional[int] = None
    common_name: str
    scientific_name: Optional[str] = None
    water_type: Optional[str] = None
    max_size: Optional[float] = None
    temperament: Optional[str] = None
    temperature_range: Optional[str] = None
    ph_range: Optional[str] = None
    habitat_type: Optional[str] = None
    social_behavior: Optional[str] = None
    tank_level: Optional[str] = None
    minimum_tank_size: Optional[int] = None
    compatibility_notes: Optional[str] = None
    diet: Optional[str] = None
    lifespan: Optional[str] = None
    care_level: Optional[str] = None
    preferred_food: Optional[str] = None
    feeding_frequency: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# Include all relevant classes and functions in __all__
__all__ = ["LightweightFishClassifier", "val_transforms", "FishSpecies"]