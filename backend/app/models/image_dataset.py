from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from enum import Enum

class DatasetType(str, Enum):
    TRAINING = "training"
    VALIDATION = "validation"
    TEST = "test"

class ImageDataset(BaseModel):
    id: Optional[int] = None
    fish_name: str
    image_data: bytes
    dataset_type: DatasetType
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    metadata: Optional[dict] = None

    class Config:
        from_attributes = True
