from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class TrainedModel(BaseModel):
    id: Optional[int] = None
    model_name: str
    version: str
    accuracy: float
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    training_metrics: Optional[str] = None
    model_path: Optional[str] = None
    description: Optional[str] = None

    class Config:
        from_attributes = True
