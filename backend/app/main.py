from fastapi import FastAPI, Depends, HTTPException, File, UploadFile, Body, Query, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Dict, Any, Optional, Tuple
import torch
import torch.nn as nn
from torchvision import transforms
from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
from PIL import Image, UnidentifiedImageError
import io
from pathlib import Path
import os
from itertools import combinations
import random
from ultralytics import YOLO
import numpy as np
import logging
import torchvision.transforms.functional as TF
import traceback
import base64
import requests
from datetime import datetime, timezone, timedelta
import asyncio
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor
import gc
import psutil
import time

from .supabase_config import get_supabase_client
from .models.train_cnn import create_large_scale_model
from .models import FishSpecies
from .routes.fish_images import router as fish_images_router
from .routes.model_management import router as model_management_router
from .routes.payments import router as payments_router
from supabase import Client

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global model variables
yolo_model = None
classifier_model = None
idx_to_common_name = {}
class_names = []
model_lock = asyncio.Lock()
model_loading_task = None
models_loaded = False
model_load_error = None

# Constrain threads to reduce memory footprint on small instances
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("NUMEXPR_NUM_THREADS", "1")
try:
    torch.set_num_threads(1)
except Exception:
    pass

# Thread pool for CPU-intensive tasks (keep minimal)
executor = ThreadPoolExecutor(max_workers=1)

app = FastAPI(
    title="AquaSync API",
    description="API for fish species identification, compatibility, and aquarium management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE_MB = 5

# Use the same validation preprocessing as training (image_size = 260)
transform = transforms.Compose([
    transforms.Resize(int(260 * 1.14)),
    transforms.CenterCrop(260),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

class FishGroup(BaseModel):
    fish_names: List[str]

class CreatePaymentIntentRequest(BaseModel):
    user_id: str
    tier_plan: str
    payment_methods: List[str] = ["card", "gcash", "grab_pay", "paymaya"]

class PaymentIntentRequest(BaseModel):
    user_id: str
    tier_plan: str
    payment_methods: Optional[List[str]] = ["card", "gcash", "grab_pay", "paymaya"]

# Memory monitoring utility
def get_memory_usage():
    """Get current memory usage in MB"""
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024

def log_memory_usage(context: str):
    """Log memory usage with context"""
    memory_mb = get_memory_usage()
    logger.info(f"Memory usage at {context}: {memory_mb:.2f} MB")

# Helper function to determine if a fish species can coexist with itself
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
    if "aggressive" in temperament_lower:
        return 2
    if "semi-aggressive" in temperament_lower:
        return 1
    if "peaceful" in temperament_lower or "community" in temperament_lower:
        return 0
    if "territorial" in temperament_lower and "peaceful" not in temperament_lower:
        return 1
    return 0

def check_pairwise_compatibility(fish1: Dict[str, Any], fish2: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Checks if two fish are compatible based on a set of explicit rules.

    Args:
        fish1: A dictionary containing the details of the first fish.
        fish2: A dictionary containing the details of the second fish.

    Returns:
        A tuple containing a boolean for compatibility and a list of reasons if not compatible.
    """
    reasons = []

    # Rule 1: Water Type
    if fish1.get('water_type') != fish2.get('water_type'):
        reasons.append(f"Water type mismatch: {fish1.get('water_type')} vs {fish2.get('water_type')}")

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

    # Rule 2: Size Difference (general)
    try:
        if (size1 > 0 and size2 > 0) and (size1 / size2 >= 2 or size2 / size1 >= 2):
            reasons.append("Significant size difference may lead to predation or bullying.")
    except Exception:
        logger.warning("Could not parse size for compatibility check.")

    # Rule 3: Temperament
    if temp1_score == 2 and temp2_score == 0:
        reasons.append(f"Temperament conflict: '{temp1_str}' fish cannot be kept with '{temp2_str}' fish.")
    if temp2_score == 2 and temp1_score == 0:
        reasons.append(f"Temperament conflict: '{temp2_str}' fish cannot be kept with '{temp1_str}' fish.")

    # New Rule 3b: Aggressive vs Aggressive is high-risk
    if temp1_score == 2 and temp2_score == 2:
        reasons.append("Both fish are aggressive; high risk of severe fighting and territorial disputes.")

    # New Rule 3c: Territorial or Solitary behavior
    if ("solitary" in behavior1) or ("solitary" in behavior2):
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

    # New Rule 7: Predation risk using size and temperament
    try:
        if size1 > 0 and size2 > 0:
            ratio = max(size1, size2) / min(size1, size2) if min(size1, size2) > 0 else None
            if ratio and ratio >= 1.5 and (is_pred1 or is_pred2 or temp1_score >= 1 or temp2_score >= 1):
                reasons.append("Size imbalance with predatory/territorial temperament increases predation/bullying risk.")
    except Exception:
        pass

    # New Rule 7b: Diet-based risks (using 'diet' and 'preferred_food')
    def _diet_category(diet: str, pref: str) -> str:
        s = f"{diet} {pref}".lower()
        if any(k in s for k in ["piscivore", "feeds on fish", "fish-based", "fish prey"]):
            return "piscivore"
        if "carniv" in s or any(k in s for k in ["meat", "predator", "live food"]):
            return "carnivore"
        if "herbiv" in s or any(k in s for k in ["algae", "vegetable", "plant"]):
            return "herbivore"
        if "omniv" in s:
            return "omnivore"
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

def download_file_with_retry(storage, object_key: str, max_retries: int = 3, retry_delay: float = 2.0) -> bytes:
    """Download file from Supabase storage with retry logic"""
    for attempt in range(max_retries):
        try:
            logger.info(f"Downloading {object_key}, attempt {attempt + 1}/{max_retries}")
            data = storage.download(object_key)
            if data:
                logger.info(f"Successfully downloaded {object_key}, size: {len(data)} bytes")
                return data
            else:
                raise RuntimeError(f"Empty data received for {object_key}")
        except Exception as e:
            logger.warning(f"Download attempt {attempt + 1} failed for {object_key}: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay * (2 ** attempt))  # Exponential backoff
            else:
                raise RuntimeError(f"Failed to download {object_key} after {max_retries} attempts: {e}")

# Deprecated: class names are read from the training checkpoint to ensure consistent label order
def load_class_names_sync() -> List[str]:
    raise RuntimeError("load_class_names_sync should not be used. Class names are loaded from the model checkpoint.")

def load_yolo_model_sync(model_path: str) -> YOLO:
    """Synchronously load YOLO model"""
    try:
        log_memory_usage("before YOLO load")
        model = YOLO(model_path)
        model.to("cpu")
        # Force garbage collection
        gc.collect()
        log_memory_usage("after YOLO load")
        logger.info("Successfully loaded YOLO model")
        return model
    except Exception as e:
        logger.error(f"Failed to load YOLO model: {e}")
        raise

def _parse_arch_from_config(model_config: Dict[str, Any]) -> str:
    arch = model_config.get('architecture', 'efficientnet_b2')
    # Expect values like 'efficientnet_b2' or 'efficientnet_b3'; convert to 'b2' / 'b3'
    if isinstance(arch, str) and arch.startswith('efficientnet_'):
        return arch.split('_')[-1]
    return arch  # already 'b2'/'b3'/'b0'

def load_classifier_model_sync(model_path: str) -> Tuple[torch.nn.Module, List[str]]:
    """Synchronously load classifier model and class names from checkpoint.

    Returns: (model, class_names)
    """
    try:
        log_memory_usage("before classifier load")

        checkpoint = torch.load(model_path, map_location="cpu")

        # Determine if we were given a raw state_dict or a full checkpoint
        if isinstance(checkpoint, dict) and 'model_state_dict' in checkpoint:
            model_state = checkpoint['model_state_dict']
            class_names_local = checkpoint.get('class_names') or []
            num_classes = checkpoint.get('num_classes') or (len(class_names_local) if class_names_local else None)
            model_config = checkpoint.get('model_config', {})
            architecture = _parse_arch_from_config(model_config)
        else:
            # Raw state dict fallback (not preferred). Require a num_classes hint.
            model_state = checkpoint
            class_names_local = []
            num_classes = None
            architecture = 'b2'

        if num_classes is None:
            raise RuntimeError("num_classes not found in checkpoint and cannot be inferred.")

        # Build the exact architecture used in training
        model = create_large_scale_model(
            num_classes=num_classes,
            architecture=architecture,
            dropout_rate=0.3,
            device=torch.device('cpu'),
            use_pretrained=False  # avoid downloading torchvision weights during inference
        )

        try:
            model.load_state_dict(model_state, strict=True)
            logger.info("Successfully loaded model state_dict from checkpoint")
        except Exception as e:
            logger.warning(f"Strict load failed: {e}. Retrying with strict=False")
            model.load_state_dict(model_state, strict=False)

        model.to("cpu").float().eval()

        # Clear memory
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        log_memory_usage("after classifier load")
        return model, class_names_local
    except Exception as e:
        logger.error(f"Failed to load classifier model/checkpoint: {e}")
        raise

async def load_models_background():
    """Background task to load models with proper error handling"""
    global yolo_model, classifier_model, idx_to_common_name, class_names
    global models_loaded, model_load_error
    
    try:
        log_memory_usage("start model loading")
        logger.info("Starting background model loading...")

        # Step 1: Get YOLO from storage, but load classifier checkpoint from local disk
        storage = get_supabase_client().storage.from_("models")
        try:
            logger.info("Fetching YOLO weights from storage and classifier checkpoint from disk...")
            yolo_data = await asyncio.get_event_loop().run_in_executor(
                executor, download_file_with_retry, storage, "yolov8n.pt"
            )

            # Resolve local checkpoint path
            # Base directory is this file's directory: backend/app/
            base_dir = Path(__file__).resolve().parent
            ckpt_path = base_dir / "models" / "trained_models" / "efficientnet_b3_fish_classifier_checkpoint.pth"
            if not ckpt_path.exists():
                raise FileNotFoundError(f"Checkpoint not found at {ckpt_path}")

            logger.info(f"Using local classifier checkpoint at: {ckpt_path}")
        except Exception as e:
            logger.error(f"Failed to prepare model files: {e}")
            model_load_error = f"Model file error: {e}"
            return
        
        # Step 3: Save to temporary files and load models
        try:
            # Create temporary file for YOLO weights
            with tempfile.NamedTemporaryFile(delete=False, suffix=".pt") as yolo_temp:
                yolo_temp.write(yolo_data)
                yolo_path = yolo_temp.name
            # Free the in-memory buffer ASAP
            try:
                del yolo_data
            except NameError:
                pass
            
            # Load models sequentially to reduce peak memory usage
            logger.info("Loading classifier model (sequential)...")
            classifier_loaded = await asyncio.get_event_loop().run_in_executor(
                executor, load_classifier_model_sync, str(ckpt_path)
            )
            classifier_model, class_names = classifier_loaded

            logger.info("Loading YOLO model (sequential)...")
            yolo_loaded = await asyncio.get_event_loop().run_in_executor(
                executor, load_yolo_model_sync, yolo_path
            )
            # assign after successful load
            globals()['yolo_model'] = yolo_loaded
            idx_to_common_name = {i: name for i, name in enumerate(class_names)}
            
            # Cleanup temp files
            try:
                os.unlink(yolo_path)
                # no unlink for local checkpoint
            except Exception as e:
                logger.warning(f"Failed to cleanup temp files: {e}")
            
            models_loaded = True
            log_memory_usage("model loading complete")
            logger.info("✅ All models loaded successfully in background!")
            
        except Exception as e:
            logger.error(f"Failed to load models: {e}")
            model_load_error = f"Model loading error: {e}"
            return
        
    except Exception as e:
        logger.error(f"Unexpected error during model loading: {e}")
        model_load_error = f"Unexpected error: {e}"
    finally:
        # Always clean up memory
        gc.collect()

async def ensure_models_loaded():
    """Ensure models are loaded, with proper waiting and error handling"""
    global model_loading_task, models_loaded, model_load_error
    
    if models_loaded:
        return
    
    if model_load_error:
        raise HTTPException(
            status_code=503, 
            detail=f"Models failed to load: {model_load_error}. Please try again later."
        )
    
    # Start loading if not already started
    if model_loading_task is None:
        model_loading_task = asyncio.create_task(load_models_background())
    
    # Wait for loading with timeout
    try:
        await asyncio.wait_for(model_loading_task, timeout=300.0)  # 5 minute timeout
    except asyncio.TimeoutError:
        model_load_error = "Model loading timed out"
        raise HTTPException(
            status_code=503,
            detail="Models are taking too long to load. Please try again later."
        )
    
    if model_load_error:
        raise HTTPException(
            status_code=503,
            detail=f"Models failed to load: {model_load_error}"
        )
    
    if not models_loaded:
        raise HTTPException(
            status_code=503,
            detail="Models failed to load for unknown reasons"
        )

@app.on_event("startup")
async def setup_app():
    """Lightweight startup - start model loading in background without blocking"""
    global model_loading_task
    
    # Create directory for training charts if it doesn't exist
    charts_dir = "app/models/trained_models/training_charts"
    os.makedirs(charts_dir, exist_ok=True)
    logger.info(f"Ensuring training charts directory exists at: {charts_dir}")

    # Mount static files for training charts
    try:
        app.mount("/app/models/trained_models/training_charts", StaticFiles(directory=charts_dir), name="training_charts")
        logger.info(f"Successfully mounted static files from {charts_dir}")
    except Exception as e:
        logger.error(f"Error mounting static files directory: {str(e)}")

    # Include routers
    app.include_router(fish_images_router)
    app.include_router(model_management_router)
    app.include_router(payments_router)
    
    # Do NOT load models at startup to keep memory low on small instances
    logger.info("Startup complete. Models will load lazily on first request.")

@app.on_event("shutdown")
async def shutdown_app():
    """Cleanup on shutdown"""
    executor.shutdown(wait=True)
    logger.info("Application shutdown complete")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint with model status"""
    global models_loaded, model_load_error
    
    memory_mb = get_memory_usage()
    
    return {
        "status": "healthy",
        "models_loaded": models_loaded,
        "model_load_error": model_load_error,
        "memory_usage_mb": round(memory_mb, 2),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

@app.get("/models/status")
async def get_model_status():
    """Get detailed model loading status"""
    global models_loaded, model_load_error, model_loading_task
    
    status = {
        "models_loaded": models_loaded,
        "model_load_error": model_load_error,
        "loading_in_progress": model_loading_task is not None and not model_loading_task.done(),
        "class_count": len(class_names),
        "memory_usage_mb": round(get_memory_usage(), 2)
    }
    
    if model_loading_task and model_loading_task.done():
        status["loading_completed"] = True
        if model_loading_task.exception():
            status["loading_exception"] = str(model_loading_task.exception())
    
    return status

@app.post("/predict", 
    summary="Identify fish species from an image",
    description="""
    Upload an image to identify the fish species. The API will:
    1. Use YOLOv8 to detect fish in the image
    2. Crop the detected fish and classify it using the CNN model
    3. Return detailed information about the identified species
    
    Supported image formats: JPG, JPEG, PNG
    Maximum file size: 5 MB
    This endpoint provides the most accurate identification, including test-time augmentation, confidence calibration, and threshold filtering.
    """,
    response_description="Fish species identification details with confidence scores"
)
async def predict(
    file: UploadFile = File(..., description="Image file containing a fish to identify"),
    db: Client = Depends(get_supabase_client)
):
    # Ensure models are loaded
    await ensure_models_loaded()

    filename = file.filename.lower()
    ext = filename.split(".")[-1]
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid file type. Only JPG/PNG allowed.")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large. Max {MAX_FILE_SIZE_MB}MB allowed.")

    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Uploaded file is not a valid image.")

    try:
        # First, use YOLO to detect fish with smaller inference size to reduce memory
        results = yolo_model(image, imgsz=384, device='cpu')
        
        # Check if any fish was detected
        if len(results[0].boxes) == 0:
            return JSONResponse(
                status_code=400,
                content={
                    "detail": "No fish detected in the image. Please try again with a clearer image of a fish.",
                    "has_fish": False
                }
            )

        # Get the box with highest confidence
        boxes = results[0].boxes
        confidences = boxes.conf.cpu().numpy()
        best_box_idx = np.argmax(confidences)
        best_box = boxes[best_box_idx]
        
        # Extract the region with the detected fish
        x1, y1, x2, y2 = map(int, best_box.xyxy[0].cpu().numpy())
        fish_image = image.crop((x1, y1, x2, y2))
        
        # Simplified test-time augmentation for better performance
        class_probs = None
        # Disable TTA to reduce memory usage on small instances
        augmentations = [
            lambda img: img,
        ]
        
        logger.info(f"Performing test-time augmentation with {len(augmentations)} variants")
        
        # Process each augmentation
        with torch.no_grad():
            for i, augment in enumerate(augmentations):
                # Apply the augmentation
                aug_image = augment(fish_image)
                
                # Preprocess and predict
                device = torch.device("cpu")
                input_tensor = transform(aug_image).unsqueeze(0).to(device)
                outputs = classifier_model(input_tensor)
                probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
                
                # Accumulate probabilities
                if class_probs is None:
                    class_probs = probabilities
                else:
                    class_probs += probabilities
            
            # Average the predictions
            class_probs /= len(augmentations)
            
            # Apply temperature scaling to calibrate confidence
            temperature = 0.4  # Values < 1 sharpen confidence (increase confidence)
            scaled_logits = torch.log(class_probs) / temperature
            calibrated_probs = torch.nn.functional.softmax(scaled_logits, dim=0)
            
            confidence, pred_idx = torch.max(calibrated_probs, 0)
            class_idx = pred_idx.item()
            score = confidence.item()

        logger.info(f"Prediction after test-time augmentation: class={class_idx}, raw confidence={score:.4f}, temperature={temperature}")
        
        # Release detection intermediates to reduce memory
        try:
            del results, boxes, best_box
        except Exception:
            pass
        gc.collect()
        
        # Set a confidence threshold to filter out uncertain predictions
        CONFIDENCE_THRESHOLD = 0.3  # Minimum acceptable confidence
        
        if score < CONFIDENCE_THRESHOLD:
            logger.warning(f"Low confidence prediction: {score:.4f} below threshold {CONFIDENCE_THRESHOLD}")
            
            # Get top 3 predictions to provide alternatives
            top_values, top_indices = torch.topk(calibrated_probs, 3)
            top_predictions = [
                {
                    "class_name": idx_to_common_name[idx.item()],
                    "confidence": val.item()
                } for val, idx in zip(top_values, top_indices)
            ]
            
            return JSONResponse(
                status_code=200,
                content={
                    "has_fish": True,
                    "detection_confidence": float(confidences[best_box_idx]),
                    "low_confidence": True,
                    "message": "Low confidence prediction. Consider taking a clearer photo.",
                    "top_predictions": top_predictions
                }
            )

        common_name = idx_to_common_name[class_idx]
        
        # Use a more flexible query that's case-insensitive
        response = db.table('fish_species').select('*').ilike('common_name', common_name).execute()
        match = response.data[0] if response.data else None

        if not match:
            # Try a fallback approach with substring matching
            response = db.table('fish_species').select('*').ilike('common_name', common_name).execute()
            possible_matches = response.data if response.data else None
            
            if possible_matches:
                # Use the closest match if there are multiple
                match = possible_matches[0]
                logger.warning(f"Used fuzzy matching for fish: '{common_name}' → '{match['common_name']}'")
            else:
                return JSONResponse(status_code=404, content={
                    "detail": f"Fish '{common_name}' not found in database.",
                    "has_fish": True,
                    "predicted_name": common_name,
                    "classification_confidence": round(score, 4)
                })

        # Get top 3 predictions for transparency (use calibrated probabilities)
        top_values, top_indices = torch.topk(calibrated_probs, min(3, len(class_names)))
        top_predictions = [
            {
                "class_name": idx_to_common_name[idx.item()],
                "confidence": round(val.item(), 4)
            } for val, idx in zip(top_values, top_indices)
        ]

        return {
            "has_fish": True,
            "detection_confidence": float(confidences[best_box_idx]),
            "common_name": match.get('common_name', 'Unknown'),
            "scientific_name": match.get('scientific_name', 'Unknown'),
            "water_type": match.get('water_type', 'Unknown'),
            "max_size": f"{match.get('max_size_(cm)', 'Unknown')} cm",
            "temperament": match.get('temperament', 'Unknown'),
            "care_level": match.get('care_level', 'Unknown'),
            "lifespan": match.get('lifespan', 'Unknown'),
            "diet": match.get('diet', 'Unknown'),
            "preferred_food": match.get('preferred_food', 'Unknown'),
            "feeding_frequency": match.get('feeding_frequency', 'Unknown'),
            "temperature_range_c": match.get('temperature_range_(Â°c)', match.get('temperature_range_c', match.get('temperature_range', 'Unknown'))),
            "ph_range": match.get('ph_range', 'Unknown'),
            "social_behavior": match.get('social_behavior', 'Unknown'),
            "minimum_tank_size_l": match.get('minimum_tank_size_(l)', match.get('minimum_tank_size_l', 'Unknown')),
            "classification_confidence": round(score, 4),
            "top_predictions": top_predictions
        }

    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.get("/fish-list")
async def get_fish_list(db: Client = Depends(get_supabase_client)):
    try:
        response = db.table('fish_species').select('*').execute()
        fish_list = []
        for fish in response.data:
            fish_copy = dict(fish)
            # Alias for frontend
            fish_copy['max_size'] = fish.get('max_size_(cm)')
            fish_copy['temperature_range'] = fish.get('temperature_range_(Â°c)')
            fish_list.append(fish_copy)
        return fish_list
    except Exception as e:
        logger.error(f"Error fetching fish list: {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching fish list")

@app.get("/fish-image/{fish_name}")
async def get_fish_image(
    fish_name: str,
    debug: bool = False,
    db: Client = Depends(get_supabase_client),
):
    """Return a random image URL for a fish from Supabase Storage.

    Looks in bucket 'models' under folder 'fish-images/{common_name}' where
    common_name removes spaces and non-alphanumeric (e.g., 'Kuhli Loach' -> 'KuhliLoach').
    Returns a public URL if available, otherwise a signed URL valid for 1 hour.
    """
    import re
    import random

    def _folder_from_name(name: str) -> str:
        # Remove spaces and non-alphanumeric characters
        no_spaces = name.replace(' ', '')
        return re.sub(r"[^A-Za-z0-9_-]", "", no_spaces)

    try:
        # Use the 'fish-images' bucket as shown in storage
        storage = db.storage.from_("fish-images")
        base = "raw_fish_images"
        # Try multiple variants to be resilient to naming differences
        variants = []
        provided = fish_name.strip()
        if provided:
            variants.append(f"{base}/{provided}")
            # Title Case variant (e.g., betta -> Betta, african cichlid -> African Cichlid)
            variants.append(f"{base}/{provided.title()}")
        # Sanitized no-space variant (e.g., AfricanCichlid)
        variants.append(f"{base}/{_folder_from_name(provided)}")

        items = []
        folder = None
        tried_paths = []
        for candidate in variants:
            try:
                # Try without and with trailing slash to handle SDK differences
                for path_variant in (candidate, f"{candidate}/"):
                    tried_paths.append(path_variant)
                    lst = storage.list(path=path_variant) or []
                    # Keep only files (exclude subfolders)
                    file_items = []
                    for it in lst:
                        # supabase-py may return dicts; detect folder by id/name ending with '/'
                        nm = getattr(it, 'name', None) or (it.get('name') if isinstance(it, dict) else None)
                        is_folder = bool(nm and str(nm).endswith('/'))
                        if not is_folder and nm:
                            file_items.append(it)
                    if file_items:
                        items = file_items
                        folder = path_variant.rstrip('/')
                        break
                if items:
                    break
            except Exception:
                continue
        if not items or not folder:
            detail = {"message": f"No images found for fish: {fish_name}"}
            if debug:
                detail["tried_paths"] = tried_paths
            raise HTTPException(status_code=404, detail=detail)

        choice = random.choice(items)
        name = getattr(choice, 'name', None) or choice.get('name') if isinstance(choice, dict) else None
        if not name:
            raise HTTPException(status_code=404, detail=f"No image files found for fish: {fish_name}")

        file_path = f"{folder}/{name}"

        def _extract_url(val):
            # Handle both string and dict return types from supabase-py
            if not val:
                return None
            if isinstance(val, str):
                return val
            if isinstance(val, dict):
                # Common keys in supabase clients
                for k in ("publicUrl", "public_url", "signedURL", "signedUrl", "signed_url", "url"):
                    if k in val and isinstance(val[k], str) and val[k]:
                        return val[k]
            return None

        try:
            public_val = storage.get_public_url(file_path)
            url = _extract_url(public_val)
            if not url:
                signed_val = storage.create_signed_url(file_path, 3600)
                url = _extract_url(signed_val)
        except Exception:
            # Fallback to signed URL if public fails
            signed_val = storage.create_signed_url(file_path, 3600)
            url = _extract_url(signed_val)

        if not url:
            raise HTTPException(status_code=500, detail="Failed to generate image URL")

        return {"url": url, "file": name}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching fish image from storage: {e}")
        raise HTTPException(status_code=500, detail="Error fetching fish image")

@app.get("/fish-species")
async def get_fish_species(db: Client = Depends(get_supabase_client)):
    try:
        response = db.table('fish_species').select('common_name').execute()
        return [fish['common_name'] for fish in response.data]
    except Exception as e:
        logger.error(f"Error fetching fish species: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching fish species: {str(e)}")

@app.get("/fish-species/all")
async def get_all_fish_species(db: Client = Depends(get_supabase_client)):
    """Get all fish species with all columns."""
    try:
        response = db.table('fish_species').select('*').execute()
        return response.data
    except Exception as e:
        logger.error(f"Error fetching full fish species data: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching fish species: {str(e)}")

@app.post("/check-group")
async def check_group_compatibility(payload: FishGroup, db: Client = Depends(get_supabase_client)):
    # Cache for fish data and images to avoid redundant DB calls
    fish_data_cache = {}
    fish_image_cache = {}
    
    async def fetch_fish_data(fish_name: str):
        if fish_name in fish_data_cache:
            return fish_data_cache[fish_name]
        
        response = db.table('fish_species').select('*').ilike('common_name', fish_name).execute()
        fish_data = response.data[0] if response.data else None
        fish_data_cache[fish_name] = fish_data
        return fish_data

    async def fetch_fish_image_base64(fish_name: str) -> str:
        if fish_name in fish_image_cache:
            return fish_image_cache[fish_name]
            
        response = db.table('fish_images_dataset').select('*').ilike('common_name', fish_name).execute()
        images = response.data if response.data else []
        
        image_result = None
        if images:
            image = random.choice(images)
            image_data = image.get('image_data')
            if image_data:
                if isinstance(image_data, str) and image_data.startswith('data:image'):
                    image_result = image_data
                elif isinstance(image_data, str):
                    image_result = f"data:image/jpeg;base64,{image_data}"
                else:
                    image_result = f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
        
        fish_image_cache[fish_name] = image_result
        return image_result

    try:
        fish_names = payload.fish_names
        if len(fish_names) < 2:
            raise HTTPException(status_code=400, detail="Please provide at least two fish names.")

        logger.info(f"Checking compatibility for fish: {fish_names}")
        
        # Pre-fetch all unique fish data to reduce DB calls
        unique_fish_names = list(set(fish_names))
        for fish_name in unique_fish_names:
            await fetch_fish_data(fish_name)
            await fetch_fish_image_base64(fish_name)
        
        pairwise_combinations = list(combinations(fish_names, 2))
        results = []

        for fish1_name, fish2_name in pairwise_combinations:
            logger.info(f"Checking pair: {fish1_name} and {fish2_name}")
            
            # Use cached data
            fish1 = fish_data_cache.get(fish1_name)
            fish2 = fish_data_cache.get(fish2_name)
            
            if not fish1:
                raise HTTPException(status_code=404, detail=f"Fish not found: {fish1_name}")
            if not fish2:
                raise HTTPException(status_code=404, detail=f"Fish not found: {fish2_name}")

            # Use cached images
            fish1_image = fish_image_cache.get(fish1_name)
            fish2_image = fish_image_cache.get(fish2_name)

            reasons = []
            compatibility_str = "Compatible"

            # Special case: Check if the same fish species is compared against itself
            if fish1_name.lower() == fish2_name.lower():
                is_compatible, reason = can_same_species_coexist(fish1_name, fish1)
                if not is_compatible:
                    reasons.append(reason)
            else:
                # Use the new rule-based compatibility check
                is_pair_compatible, rule_reasons = check_pairwise_compatibility(fish1, fish2)
                if not is_pair_compatible:
                    reasons.extend(rule_reasons)
            
            if reasons:
                compatibility_str = "Not Compatible"
            else:
                reasons.append("These fish are generally compatible.")

            results.append({
                "pair": [fish1['common_name'], fish2['common_name']],
                "compatibility": compatibility_str,
                "reasons": reasons,
                "fish1_image": fish1_image,
                "fish2_image": fish2_image
            })
            
        return {"results": results}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in check_group_compatibility: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

class WaterRequirementsRequest(BaseModel):
    fish_selections: dict[str, int]  # fish name -> quantity

@app.post("/calculate-water-requirements/")
def calculate_water_requirements(request: WaterRequirementsRequest, db: Client = Depends(get_supabase_client)):
    try:
        fish_selections = request.fish_selections
        
        if not fish_selections:
            return JSONResponse(
                status_code=400,
                content={"error": "No fish selected"}
            )

        # Initialize variables with extreme values
        min_temp = float('-inf')
        max_temp = float('inf')
        min_ph = float('-inf')
        max_ph = float('inf')
        total_volume = 0
        fish_details = []

        # Calculate requirements for each fish
        for fish_name, quantity in fish_selections.items():
            if quantity <= 0:
                continue

            response = db.table('fish_species').select('*').eq('common_name', fish_name).execute()
            fish_info = response.data[0] if response.data else None
            
            if not fish_info:
                return JSONResponse(
                    status_code=404,
                    content={"error": f"Fish not found: {fish_name}"}
                )
            
            # Parse temperature range (try all possible fields)
            temp_min, temp_max = parse_range(
                fish_info.get('temperature_range_c') or
                fish_info.get('temperature_range_(Â°c)') or
                fish_info.get('temperature_range') or
                None
            )
            if temp_min is not None:
                min_temp = max(min_temp, temp_min)
            if temp_max is not None:
                max_temp = min(max_temp, temp_max)

            # Parse pH range (try all possible fields)
            ph_min, ph_max = parse_range(
                fish_info.get('ph_range') or
                fish_info.get('pH_range') or
                None
            )
            if ph_min is not None:
                min_ph = max(min_ph, ph_min)
            if ph_max is not None:
                max_ph = min(max_ph, ph_max)

            # Calculate tank volume
            min_tank_size = None
            for key in ['minimum_tank_size_l', 'minimum_tank_size_(l)', 'minimum_tank_size']:
                val = fish_info.get(key)
                if val is not None:
                    try:
                        min_tank_size = float(val)
                        break
                    except (ValueError, TypeError):
                        continue
            if min_tank_size is None or min_tank_size <= 0:
                return JSONResponse(
                    status_code=400,
                    content={"error": f"Fish '{fish_name}' has invalid or missing minimum tank size in the database."}
                )
            total_volume += min_tank_size * quantity

            # Add fish details to response
            fish_details.append({
                "name": fish_name,
                "quantity": quantity,
                "individual_requirements": {
                    "temperature": fish_info.get('temperature_range_c') or fish_info.get('temperature_range_(Â°c)') or fish_info.get('temperature_range', 'Unknown'),
                    "pH": fish_info.get('ph_range') or fish_info.get('pH_range', 'Unknown'),
                    "minimum_tank_size": f"{min_tank_size} L"
                }
            })

        # Check if ranges are compatible
        if min_temp > max_temp or min_ph > max_ph:
            return JSONResponse(
                status_code=400,
                content={
                    "error": "Incompatible fish requirements",
                    "details": "The selected fish have incompatible temperature or pH requirements.",
                    "fish_details": fish_details
                }
            )

        # If any value is still -inf/inf, set to 'Unknown'
        min_temp = round(min_temp, 1) if min_temp != float('-inf') else 'Unknown'
        max_temp = round(max_temp, 1) if max_temp != float('inf') else 'Unknown'
        min_ph = round(min_ph, 1) if min_ph != float('-inf') else 'Unknown'
        max_ph = round(max_ph, 1) if max_ph != float('inf') else 'Unknown'
        total_volume = round(total_volume, 1)

        return {
            "requirements": {
                "temperature_range": f"{min_temp}°C - {max_temp}°C" if min_temp != 'Unknown' and max_temp != 'Unknown' else 'Unknown',
                "pH_range": f"{min_ph} - {max_ph}" if min_ph != 'Unknown' and max_ph != 'Unknown' else 'Unknown',
                "minimum_tank_volume": f"{total_volume} L"
            },
            "fish_details": fish_details
        }

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Calculation failed: {str(e)}"}
        )

class TankCapacityRequest(BaseModel):
    tank_volume: float
    fish_selections: dict[str, int]  # fish name -> quantity

@app.post("/calculate-fish-capacity/")
def calculate_fish_capacity(request: TankCapacityRequest, db: Client = Depends(get_supabase_client)):
    try:
        tank_volume = request.tank_volume
        fish_selections = request.fish_selections
        
        if not fish_selections:
            return JSONResponse(
                status_code=400,
                content={"error": "No fish selected"}
            )

        # Initialize variables
        min_temp = float('-inf')
        max_temp = float('inf')
        min_ph = float('-inf')
        max_ph = float('inf')
        fish_details = []
        compatibility_issues = []
        fish_info_map = {}
        species_rules: Dict[str, Dict[str, Any]] = {}
        species_notes: Dict[str, List[str]] = {}

        # First pass: Get fish information and gather rules
        for fish_name in fish_selections.keys():
            response = db.table('fish_species').select('*').eq('common_name', fish_name).execute()
            fish_info = response.data[0] if response.data else None
            
            if not fish_info:
                return JSONResponse(
                    status_code=404,
                    content={"error": f"Fish not found: {fish_name}"}
                )
            fish_info_map[fish_name] = fish_info
            species_notes.setdefault(fish_name, [])
            
            # Parse temperature range (try all possible fields)
            temp_min, temp_max = parse_range(
                fish_info.get('temperature_range_c') or
                fish_info.get('temperature_range_(Â°c)') or
                fish_info.get('temperature_range') or
                None
            )
            if temp_min is not None:
                min_temp = max(min_temp, temp_min)
            if temp_max is not None:
                max_temp = min(max_temp, temp_max)

            # Parse pH range (try all possible fields)
            ph_min, ph_max = parse_range(
                fish_info.get('ph_range') or
                fish_info.get('pH_range') or
                None
            )
            if ph_min is not None:
                min_ph = max(min_ph, ph_min)
            if ph_max is not None:
                max_ph = min(max_ph, ph_max)

            # Build species-specific rules
            can_coexist, reason_same = can_same_species_coexist(fish_name, fish_info)
            behavior = str(fish_info.get('social_behavior') or '').lower()
            is_schooling = ('school' in behavior) or ('shoal' in behavior)
            min_group = 6 if is_schooling else 1
            species_rules[fish_name] = {
                "solitary": not can_coexist,
                "reason_same": reason_same,
                "schooling": is_schooling,
                "min_group": min_group,
            }
            # If user requested more than allowed for solitary species, log an issue
            if (not can_coexist) and fish_selections.get(fish_name, 0) > 1:
                compatibility_issues.append({
                    "pair": [fish_name, fish_name],
                    "reasons": [reason_same, "This species is capped to 1 per tank in recommendations."]
                })
                species_notes[fish_name].append("Capped to 1 due to conspecific aggression/solitary behavior.")

            # Enforce minimum tank size constraint per species against provided tank volume
            try:
                min_tank_size_candidate = None
                for key in ['minimum_tank_size_l', 'minimum_tank_size_(l)', 'minimum_tank_size']:
                    val = fish_info.get(key)
                    if val is not None:
                        try:
                            min_tank_size_candidate = float(val)
                            break
                        except (ValueError, TypeError):
                            continue
                if min_tank_size_candidate is not None and min_tank_size_candidate > 0:
                    if tank_volume < min_tank_size_candidate:
                        # Record as a compatibility issue and add a note so UI can surface it
                        compatibility_issues.append({
                            "pair": [fish_name, fish_name],
                            "reasons": [
                                f"Tank volume {tank_volume} L is below the minimum required size of {min_tank_size_candidate} L for {fish_name}."
                            ]
                        })
                        species_notes[fish_name].append(
                            f"Tank volume is insufficient for this species (needs at least {min_tank_size_candidate} L)."
                        )
            except Exception:
                # If parsing fails, do not block but also do not add the constraint
                pass

        # Check compatibility between different species pairs
        fish_names = list(fish_selections.keys())
        are_compatible = True
        if len(fish_names) >= 2:
            pairwise_combinations = list(combinations(fish_names, 2))
            
            for fish1_name, fish2_name in pairwise_combinations:
                fish1 = fish_info_map[fish1_name]
                fish2 = fish_info_map[fish2_name]
                is_pair_compatible, reasons = check_pairwise_compatibility(fish1, fish2)
                if not is_pair_compatible:
                    are_compatible = False
                    compatibility_issues.append({
                        "pair": [fish1_name, fish2_name],
                        "reasons": reasons
                    })

        # Calculate optimal fish distribution if compatible
        if are_compatible:
            # Calculate the minimum tank size required per fish
            min_sizes = {}
            for name, info in fish_info_map.items():
                min_tank_size = None
                for key in ['minimum_tank_size_l', 'minimum_tank_size_(l)', 'minimum_tank_size']:
                    val = info.get(key)
                    if val is not None:
                        try:
                            min_tank_size = float(val)
                            break
                        except (ValueError, TypeError):
                            continue
                if min_tank_size is None or min_tank_size <= 0:
                    return JSONResponse(
                        status_code=400,
                        content={"error": f"Fish '{name}' has invalid or missing minimum tank size in the database."}
                    )
                min_sizes[name] = min_tank_size

            # Calculate maximum fish quantities while maintaining balance
            total_space = tank_volume
            base_quantities = {}
            max_quantities = {}
            
            # Calculate maximum individual quantities first
            for fish_name, min_size in min_sizes.items():
                if min_size <= 0:
                    return JSONResponse(
                        status_code=400,
                        content={"error": f"Fish '{fish_name}' has invalid or missing minimum tank size in the database."}
                    )
                max_q = int(tank_volume / min_size)
                # Enforce solitary cap
                rules = species_rules.get(fish_name, {})
                if rules.get("solitary"):
                    max_q = min(max_q, 1)
                max_quantities[fish_name] = max_q
            
            # First, allocate minimum quantities (1 for each species)
            for fish_name, min_size in min_sizes.items():
                base_quantities[fish_name] = 1
                total_space -= min_size

            # Priority phase: bring schooling species up to their minimum group size
            for fish_name, min_size in min_sizes.items():
                rules = species_rules.get(fish_name, {})
                if rules.get("schooling"):
                    target = max(1, rules.get("min_group", 6))
                    while (
                        base_quantities[fish_name] < target and
                        base_quantities[fish_name] < max_quantities[fish_name] and
                        total_space >= min_size
                    ):
                        base_quantities[fish_name] += 1
                        total_space -= min_size
                    if base_quantities[fish_name] < target:
                        needed = target - base_quantities[fish_name]
                        species_notes[fish_name].append(
                            f"Could not reach minimum schooling group of {target}. Short by {needed} due to tank volume."
                        )
                        compatibility_issues.append({
                            "pair": [fish_name, fish_name],
                            "reasons": [f"Minimum group size for schooling species is {target}; tank volume limits this to {base_quantities[fish_name]}."]
                        })

            # Then distribute remaining space proportionally
            while total_space > 0:
                can_add_more = False
                for fish_name, min_size in min_sizes.items():
                    if total_space >= min_size and base_quantities[fish_name] < max_quantities[fish_name]:
                        base_quantities[fish_name] += 1
                        total_space -= min_size
                        can_add_more = True
                if not can_add_more:
                    break

            # Calculate actual bioload and prepare fish details
            total_bioload = 0
            for fish_name, quantity in base_quantities.items():
                fish_info = fish_info_map[fish_name]
                min_tank_size = min_sizes[fish_name]
                fish_bioload = min_tank_size * quantity
                total_bioload += fish_bioload

                fish_details.append({
                    "name": fish_name,
                    "recommended_quantity": quantity,
                    "current_quantity": fish_selections[fish_name],
                    "max_capacity": max_quantities[fish_name],
                    "individual_requirements": {
                        "temperature": fish_info.get('temperature_range_c') or fish_info.get('temperature_range_(Â°c)') or fish_info.get('temperature_range', 'Unknown'),
                        "pH": fish_info.get('ph_range') or fish_info.get('pH_range', 'Unknown'),
                        "minimum_tank_size": f"{min_tank_size} L"
                    },
                    "notes": species_notes.get(fish_name) or []
                })

        else:
            # If fish are not compatible, calculate individual maximums
            total_bioload = 0
            for fish_name in fish_selections.keys():
                fish_info = fish_info_map[fish_name]
                min_tank_size = None
                for key in ['minimum_tank_size_l', 'minimum_tank_size_(l)', 'minimum_tank_size']:
                    val = fish_info.get(key)
                    if val is not None:
                        try:
                            min_tank_size = float(val)
                            break
                        except (ValueError, TypeError):
                            continue
                if min_tank_size is None or min_tank_size <= 0:
                    return JSONResponse(
                        status_code=400,
                        content={"error": f"Fish '{fish_name}' has invalid or missing minimum tank size in the database."}
                    )
                max_fish = int(tank_volume / min_tank_size) if min_tank_size > 0 else float('inf')
                fish_bioload = min_tank_size * fish_selections[fish_name]
                total_bioload += fish_bioload

                fish_details.append({
                    "name": fish_name,
                    "recommended_quantity": "N/A (Incompatible with other species)",
                    "current_quantity": fish_selections[fish_name],
                    "max_individual_capacity": max_fish,
                    "individual_requirements": {
                        "temperature": fish_info.get('temperature_range_c') or fish_info.get('temperature_range_(Â°c)') or fish_info.get('temperature_range', 'Unknown'),
                        "pH": fish_info.get('ph_range') or fish_info.get('pH_range', 'Unknown'),
                        "minimum_tank_size": f"{min_tank_size} L"
                    },
                    "notes": species_notes.get(fish_name) or []
                })

        # If any value is still -inf/inf, set to 'Unknown'
        min_temp = round(min_temp, 1) if min_temp != float('-inf') else 'Unknown'
        max_temp = round(max_temp, 1) if max_temp != float('inf') else 'Unknown'
        min_ph = round(min_ph, 1) if min_ph != float('-inf') else 'Unknown'
        max_ph = round(max_ph, 1) if max_ph != float('inf') else 'Unknown'

        tank_status = "Adequate"
        if isinstance(total_bioload, (int, float)) and isinstance(tank_volume, (int, float)):
            if total_bioload > tank_volume:
                tank_status = "Overstocked"
            elif total_bioload < tank_volume * 0.5:
                tank_status = "Understocked"

        return {
            "tank_details": {
                "volume": f"{tank_volume} L",
                "current_bioload": f"{total_bioload} L",
                "status": tank_status
            },
            "water_conditions": {
                "temperature_range": f"{min_temp}°C - {max_temp}°C" if min_temp != 'Unknown' and max_temp != 'Unknown' else 'Unknown',
                "pH_range": f"{min_ph} - {max_ph}" if min_ph != 'Unknown' and max_ph != 'Unknown' else 'Unknown'
            },
            "fish_details": fish_details,
            "compatibility_issues": compatibility_issues
        }

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Calculation failed: {str(e)}"}
        )

@app.post("/save-fish-calculation/")
async def save_fish_calculation(payload: dict = Body(...), db: Client = Depends(get_supabase_client)):
    """
    Save a fish calculation result to the fish_calculations table in Supabase.
    Expects a JSON payload matching the table columns.
    """
    try:
        # Optionally, validate required fields here
        response = db.table('fish_calculations').insert(payload).execute()
        if hasattr(response, 'error') and response.error:
            raise HTTPException(status_code=500, detail=str(response.error))
        return {"success": True, "id": response.data[0]['id'] if response.data else None}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save calculation: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "AquaSync API is running",
        "services": {
            "compatibility": "/check-group",
            "classifier": "/predict"
        }
    }

# Get PayMongo secret key from environment
PAYMONGO_SECRET_KEY = os.getenv("PAYMONGO_SECRET_KEY")
# Do not crash the app at import time; endpoints will check this when needed
if not PAYMONGO_SECRET_KEY:
    logger.warning("PAYMONGO_SECRET_KEY is not set. Payment endpoints may not work until configured.")

# --- Payment & Subscription Utilities ---
def create_subscription(db, user_id, tier_plan, payment_intent_id):
    now = datetime.now(timezone.utc)
    next_billing = now + timedelta(days=30)
    db.table('subscriptions').insert({
        "user_id": user_id,
        "tier_plan": tier_plan,
        "status": "pending",
        "paymongo_payment_id": payment_intent_id,
        "start_date": now.isoformat(),
        "next_billing_date": next_billing.isoformat()
    }).execute()

def expire_subscriptions_and_notify(db: Client):
    now = datetime.now(timezone.utc).isoformat()
    expired = db.table('subscriptions')\
        .select('*')\
        .eq('status', 'active')\
        .lt('next_billing_date', now)\
        .execute()
    expired_user_ids = []
    for sub in expired.data:
        user_id = sub['user_id']
        db.table('subscriptions').update({
            'status': 'expired',
            'end_date': now
        }).eq('id', sub['id']).execute()
        db.table('profiles').update({
            'tier_plan': 'free'
        }).eq('id', user_id).execute()
        expired_user_ids.append(user_id)
        logger.info(f"Subscription expired for user {user_id}")
    return expired_user_ids

# --- Expose Expiry Logic as Endpoint ---
@app.post("/expire-subscriptions")
async def expire_subscriptions_endpoint(db: Client = Depends(get_supabase_client)):
    # TODO: Add authentication/authorization for admin or scheduled job
    expired_user_ids = expire_subscriptions_and_notify(db)
    return {"expired_user_ids": expired_user_ids, "message": "Expired subscriptions processed. Notify these users in the frontend."}

# --- Webhook Signature Verification ---
def verify_paymongo_signature(request: Request, raw_body: bytes) -> bool:
    """
    Always skip signature verification for PayMongo webhooks.
    PayMongo does not provide a webhook signing secret as of June 2024.
    """
    logger.warning("Skipping PayMongo webhook signature verification: no webhook secret is provided by PayMongo.")
    return True

# --- Webhook Handler (enhanced) ---
@app.post("/paymongo/webhook")
async def paymongo_webhook(request: Request, db: Client = Depends(get_supabase_client)):
    """
    Handle PayMongo webhook events for payment processing.
    Logs full request for debugging.
    """
    # Log headers and body for debugging
    logger.info(f"Received webhook request: headers={dict(request.headers)}")
    raw_body = await request.body()
    logger.info(f"Webhook raw body: {raw_body.decode(errors='replace')}")
    
    # Webhook signature verification
    if not verify_paymongo_signature(request, raw_body):
        logger.error("Webhook signature verification failed. Rejecting webhook.")
        raise HTTPException(status_code=401, detail="Invalid webhook signature")
    
    try:
        payload = await request.json()
        logger.info(f"Webhook JSON payload: {payload}")
        event_type = payload.get("data", {}).get("attributes", {}).get("type")
        # PayMongo event id (not the link/payment id)
        event_id = payload.get("data", {}).get("id")
        # The resource (link/payment) id lives under data.attributes.data.id
        resource_id = payload.get("data", {}).get("attributes", {}).get("data", {}).get("id")
        logger.info(f"Received PayMongo webhook: event_type={event_type}, event_id={event_id}, resource_id={resource_id}")
        
        # Handle different payment scenarios
        if event_type in ["link.paid", "payment.paid"]:
            await handle_successful_payment(resource_id, db, payload)
        elif event_type in ["link.failed", "payment.failed"]:
            await handle_failed_payment(resource_id, db, payload)
        elif event_type == "link.expired":
            await handle_expired_link(resource_id, db, payload)
        elif event_type == "payment.refunded":
            await handle_refunded_payment(resource_id, db, payload)
        else:
            logger.info(f"Unhandled PayMongo event type: {event_type}")
        
        return {"received": True, "event_type": event_type}
        
    except Exception as e:
        logger.error(f"Error handling PayMongo webhook: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Webhook processing failed: {str(e)}")

async def handle_successful_payment(resource_id: str, db: Client, payload: dict):
    """Handle successful payment events and update user tier_plan in profiles table.

    Priority:
    1) Use resource_id (link/payment id) to find the pending subscription row via paymongo_payment_id
       and read user_id + tier_plan from there (most reliable).
    2) Fallback to parsing the description string for user_id/tier_plan if lookup fails.
    """
    try:
        if not payload:
            logger.error("No webhook payload provided for extracting user info.")
            return
        attributes = payload.get("data", {}).get("attributes", {})
        payment_data = attributes.get("data", {}).get("attributes", {})
        description = payment_data.get("description", "")
        logger.info(f"Payment description: {description}")

        # First, try to find the subscription directly by resource_id (link/payment id)
        user_id = None
        tier_plan = None
        if resource_id:
            sub_resp = db.table('subscriptions').select('*').eq('paymongo_payment_id', resource_id).order('created_at', desc=True).limit(1).execute()
            if sub_resp.data:
                sub_row = sub_resp.data[0]
                user_id = sub_row.get('user_id')
                tier_plan = (sub_row.get('tier_plan') or '').lower()
                logger.info(f"Matched subscription row by resource_id: user_id={user_id}, tier_plan={tier_plan}")

        # If lookup failed, fall back to parsing the description
        if not user_id or not tier_plan:
            import re
            match = re.search(r"(pro_plus|pro)\s+subscription\s+for\s+user\s+([a-f0-9\-]+)", description, re.IGNORECASE)
            if match:
                tier_plan = match.group(1).lower()
                user_id = match.group(2)
                logger.info(f"Extracted from description: user_id={user_id}, tier_plan={tier_plan}")
            else:
                logger.error("Unable to determine user_id/tier_plan from webhook. Skipping update.")
                return

        now = datetime.now(timezone.utc)
        next_billing = now + timedelta(days=30)

        # Update user's tier plan
        update_profiles = db.table('profiles').update({
            'tier_plan': tier_plan,
            'updated_at': now.isoformat()
        }).eq('id', user_id).execute()
        logger.info(f"Updated profiles: {update_profiles}")

        # Update the specific subscription row if we have the resource_id; otherwise, update latest pending for user
        subs_update_query = db.table('subscriptions').update({
            'status': 'active',
            'last_payment_date': now.isoformat(),
            'next_billing_date': next_billing.isoformat(),
            'updated_at': now.isoformat()
        })
        if resource_id:
            update_subs = subs_update_query.eq('paymongo_payment_id', resource_id).execute()
        else:
            update_subs = subs_update_query.eq('user_id', user_id).eq('status', 'pending').execute()
        logger.info(f"Updated subscriptions: {update_subs}")
        logger.info(f"Subscription activated for user {user_id} with tier {tier_plan}")
    except Exception as e:
        logger.error(f"Error handling successful payment: {str(e)}")
        raise

async def handle_failed_payment(resource_id: str, db: Client, payload: dict):
    """Handle failed payment events"""
    try:
        response = db.table('subscriptions').select('*').eq('paymongo_payment_id', resource_id).execute()
        
        if not response.data:
            logger.warning(f"No subscription found for paymongo_payment_id {resource_id}")
            return
        
        subscription = response.data[0]
        user_id = subscription['user_id']
        now = datetime.now(timezone.utc)
        
        # Update subscription status
        db.table('subscriptions').update({
            'status': 'failed',
            'updated_at': now.isoformat()
        }).eq('paymongo_payment_id', resource_id).execute()
        
        # Ensure user remains on free tier
        db.table('profiles').update({
            'tier_plan': 'free',
            'updated_at': now.isoformat()
        }).eq('id', user_id).execute()
        
        logger.info(f"Payment failed for user {user_id}, subscription marked as failed")
        
    except Exception as e:
        logger.error(f"Error handling failed payment: {str(e)}")
        raise

async def handle_expired_link(resource_id: str, db: Client, payload: dict):
    """Handle expired link events"""
    try:
        response = db.table('subscriptions').select('*').eq('paymongo_payment_id', resource_id).execute()
        
        if not response.data:
            logger.warning(f"No subscription found for paymongo_payment_id {resource_id}")
            return
        
        subscription = response.data[0]
        user_id = subscription['user_id']
        now = datetime.now(timezone.utc)
        
        # Update subscription status
        db.table('subscriptions').update({
            'status': 'expired',
            'end_date': now.isoformat(),
            'updated_at': now.isoformat()
        }).eq('paymongo_payment_id', resource_id).execute()
        
        # Revert user to free tier
        db.table('profiles').update({
            'tier_plan': 'free',
            'updated_at': now.isoformat()
        }).eq('id', user_id).execute()
        
        logger.info(f"Link expired for user {user_id}, subscription marked as expired")
        
    except Exception as e:
        logger.error(f"Error handling expired link: {str(e)}")
        raise

async def handle_refunded_payment(resource_id: str, db: Client, payload: dict):
    """Handle refunded payment events"""
    try:
        response = db.table('subscriptions').select('*').eq('paymongo_payment_id', resource_id).execute()
        
        if not response.data:
            logger.warning(f"No subscription found for paymongo_payment_id {resource_id}")
            return
        
        subscription = response.data[0]
        user_id = subscription['user_id']
        now = datetime.now(timezone.utc)
        
        # Update subscription status
        db.table('subscriptions').update({
            'status': 'refunded',
            'end_date': now.isoformat(),
            'updated_at': now.isoformat()
        }).eq('paymongo_payment_id', resource_id).execute()
        
        # Revert user to free tier
        db.table('profiles').update({
            'tier_plan': 'free',
            'updated_at': now.isoformat()
        }).eq('id', user_id).execute()
        
        logger.info(f"Payment refunded for user {user_id}, subscription marked as refunded")
        
    except Exception as e:
        logger.error(f"Error handling refunded payment: {str(e)}")
        raise

# --- Payment Link Creation Endpoint ---
@app.post("/create-payment-link")
async def create_payment_link(
    user_id: str = Body(...),
    tier_plan: str = Body(...),
    db: Client = Depends(get_supabase_client)
):
    """
    Create a PayMongo payment link for subscription purchase.
    
    Args:
        user_id: The user's ID
        tier_plan: The subscription tier (pro, pro_plus)
    
    Returns:
        JSON with checkout URL and payment details
    """
    logger.info(f"Creating payment link for user {user_id}, tier {tier_plan}")
    
    plan_amounts = {
        "pro": 19900,  # ₱199
    }
    
    if tier_plan not in plan_amounts:
        logger.error(f"Invalid tier plan: {tier_plan}. Available plans: {list(plan_amounts.keys())}")
        raise HTTPException(status_code=400, detail="Invalid plan selected. Choose 'pro'.")
    
    amount = plan_amounts[tier_plan]
    description = f"{tier_plan.capitalize()} Subscription for user {user_id}"
    remarks = f"Subscription for user {user_id}"
    
    paymongo_payload = {
        "data": {
            "attributes": {
                "amount": amount,
                "description": description,
                "remarks": remarks,
                "currency": "PHP",
                "checkout_options": {
                    "redirect_url": "https://aquasync.app/payment/return"
                }
            }
        }
    }
    
    logger.info(f"PayMongo payload: {paymongo_payload}")
    logger.info(f"Using PayMongo key: {'*' * len(str(PAYMONGO_SECRET_KEY)) if PAYMONGO_SECRET_KEY else 'NOT SET'}")
    
    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "authorization": f"Basic {base64.b64encode((PAYMONGO_SECRET_KEY + ':').encode()).decode()}"
    }
    
    try:
        logger.info("Sending request to PayMongo...")
        try:
            response = requests.post(
                "https://api.paymongo.com/v1/links",
                json=paymongo_payload,
                headers=headers,
                timeout=30  # Add timeout
            )
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to connect to PayMongo: {str(e)}")
            raise HTTPException(
                status_code=503,
                detail="Unable to connect to payment service. Please try again later."
            )

        logger.info(f"PayMongo response status: {response.status_code}")
        logger.info(f"PayMongo response: {response.text}")
        
        try:
            response_data = response.json()
        except ValueError:
            logger.error("Invalid JSON response from PayMongo")
            raise HTTPException(
                status_code=500,
                detail="Invalid response from payment service"
            )

        if response.status_code not in (200, 201):
            error_detail = response_data.get('errors', [{}])[0].get('detail', 'Unknown error')
            logger.error(f"PayMongo error: {error_detail}")
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Payment service error: {error_detail}"
            )

        link_data = response_data.get("data")
        if not link_data:
            logger.error("No data in PayMongo response")
            raise HTTPException(
                status_code=500,
                detail="Invalid response from payment service"
            )
        checkout_url = link_data["attributes"]["checkout_url"]
        link_id = link_data["id"]
        logger.info(f"Successfully created payment link with ID: {link_id}")

        # Save a pending subscription with the PayMongo link ID
        now = datetime.now(timezone.utc)
        next_billing = now + timedelta(days=30)

        db.table('subscriptions').insert({
            "user_id": user_id,
            "tier_plan": tier_plan,
            "status": "pending",
            "paymongo_payment_id": link_id,
            "start_date": now.isoformat(),
            "next_billing_date": next_billing.isoformat(),
            "created_at": now.isoformat(),
            "updated_at": now.isoformat()
        }).execute()

        logger.info(f"Created payment link for user {user_id} with tier {tier_plan}")

        return JSONResponse(content={
            "checkout_url": checkout_url,
            "amount": amount,
            "tier_plan": tier_plan,
            "link_id": link_id
        })
    except Exception as e:
        logger.error(f"Error creating payment link: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to create payment link: {str(e)}")

# --- Subscription Management Endpoints ---
@app.get("/subscription/status/{user_id}")
async def get_subscription_status(user_id: str, db: Client = Depends(get_supabase_client)):
    """
    Get the current subscription status for a user.
    
    Args:
        user_id: The user's ID
    
    Returns:
        JSON with subscription details and status
    """
    try:
        # Get user's current tier plan
        profile_response = db.table('profiles').select('tier_plan').eq('id', user_id).execute()
        current_tier = profile_response.data[0]['tier_plan'] if profile_response.data else 'free'
        
        # Get active subscription details
        subscription_response = db.table('subscriptions').select('*').eq('user_id', user_id).eq('status', 'active').order('created_at', desc=True).limit(1).execute()
        
        subscription_info = None
        if subscription_response.data:
            sub = subscription_response.data[0]
            subscription_info = {
                "tier_plan": sub['tier_plan'],
                "status": sub['status'],
                "start_date": sub['start_date'],
                "next_billing_date": sub['next_billing_date'],
                "last_payment_date": sub.get('last_payment_date')
            }
        
        return {
            "user_id": user_id,
            "current_tier": current_tier,
            "subscription": subscription_info,
            "is_active": subscription_info is not None
        }
        
    except Exception as e:
        logger.error(f"Error getting subscription status for user {user_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get subscription status: {str(e)}")

@app.post("/subscription/cancel/{user_id}")
async def cancel_subscription(user_id: str, db: Client = Depends(get_supabase_client)):
    """
    Cancel a user's active subscription.
    
    Args:
        user_id: The user's ID
    
    Returns:
        JSON with cancellation confirmation
    """
    try:
        now = datetime.now(timezone.utc)
        
        # Find active subscription
        subscription_response = db.table('subscriptions').select('*').eq('user_id', user_id).eq('status', 'active').execute()
        
        if not subscription_response.data:
            raise HTTPException(status_code=404, detail="No active subscription found for this user")
        
        subscription = subscription_response.data[0]
        
        # Update subscription status
        db.table('subscriptions').update({
            'status': 'cancelled',
            'end_date': now.isoformat(),
            'updated_at': now.isoformat()
        }).eq('id', subscription['id']).execute()
        
        # Revert user to free tier
        db.table('profiles').update({
            'tier_plan': 'free',
            'updated_at': now.isoformat()
        }).eq('id', user_id).execute()
        
        logger.info(f"Subscription cancelled for user {user_id}")
        
        return {
            "success": True,
            "message": "Subscription cancelled successfully",
            "cancelled_at": now.isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling subscription for user {user_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to cancel subscription: {str(e)}")

@app.post("/subscription/reconcile/{link_id}")
async def reconcile_subscription(link_id: str, db: Client = Depends(get_supabase_client)):
    """Reconcile a subscription by checking the PayMongo link status and updating local tables.

    This is useful when webhooks are delayed or not delivered. It expects that the
    subscriptions table has a row with paymongo_payment_id == link_id.
    """
    try:
        # Find the pending/latest subscription row for this link
        sub_resp = db.table('subscriptions')\
            .select('*')\
            .eq('paymongo_payment_id', link_id)\
            .order('created_at', desc=True)\
            .limit(1)\
            .execute()

        if not sub_resp.data:
            raise HTTPException(status_code=404, detail="No subscription found for this link_id")

        sub_row = sub_resp.data[0]
        user_id = sub_row['user_id']
        tier_plan = (sub_row.get('tier_plan') or 'pro').lower()

        # Query PayMongo for the link status
        if not PAYMONGO_SECRET_KEY:
            raise HTTPException(status_code=500, detail="PAYMONGO_SECRET_KEY is not configured on the server")

        headers = {
            "accept": "application/json",
            "authorization": f"Basic {base64.b64encode((PAYMONGO_SECRET_KEY + ':').encode()).decode()}"
        }

        pm_url = f"https://api.paymongo.com/v1/links/{link_id}"
        r = requests.get(pm_url, headers=headers, timeout=30)

        try:
            data = r.json()
        except ValueError:
            raise HTTPException(status_code=502, detail="Invalid response from PayMongo")

        if r.status_code not in (200, 201):
            detail = data.get('errors', [{}])[0].get('detail', 'Unknown error')
            raise HTTPException(status_code=r.status_code, detail=f"PayMongo error: {detail}")

        link_attrs = data.get('data', {}).get('attributes', {})
        link_status = link_attrs.get('status')

        if link_status == 'paid':
            now = datetime.now(timezone.utc)
            next_billing = now + timedelta(days=30)

            # Activate subscription row
            upd_sub = db.table('subscriptions').update({
                'status': 'active',
                'last_payment_date': now.isoformat(),
                'next_billing_date': next_billing.isoformat(),
                'updated_at': now.isoformat()
            }).eq('paymongo_payment_id', link_id).execute()

            # Update profile tier
            upd_prof = db.table('profiles').update({
                'tier_plan': tier_plan,
                'updated_at': now.isoformat()
            }).eq('id', user_id).execute()

            return {
                'reconciled': True,
                'link_status': link_status,
                'subscription_update': upd_sub,
                'profile_update': upd_prof
            }
        else:
            return {
                'reconciled': False,
                'link_status': link_status,
                'message': 'Link is not paid yet'
            }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reconciling subscription for link {link_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to reconcile subscription: {str(e)}")

# --- Webhook Test Endpoint (for development) ---
@app.post("/webhook/test")
async def test_webhook(request: Request):
    """
    Test endpoint to simulate webhook events for development.
    This should be disabled in production.
    """
    try:
        payload = await request.json()
        logger.info(f"Test webhook received: {payload}")
        return {"received": True, "test": True, "payload": payload}
    except Exception as e:
        logger.error(f"Error in test webhook: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Webhook test error: {str(e)}")

# --- Diet Calculator Endpoints ---

class DietCalculationRequest(BaseModel):
    fish_selections: Dict[str, int]
    total_portion: int
    total_portion_range: Optional[str] = None
    portion_details: Dict[str, Any]
    compatibility_issues: Optional[List[str]] = None
    feeding_notes: Optional[str] = None

@app.post("/save-diet-calculation/")
async def save_diet_calculation(
    diet_request: DietCalculationRequest,
    request: Request,
    db: Client = Depends(get_supabase_client)
):
    """Save a diet calculation to the database"""
    calculation_data = None
    try:
        # Get authenticated user ID from request headers or auth token
        user_id = None
        
        # Try to get user_id from Authorization header
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            try:
                # Extract token and get user from Supabase
                token = auth_header.replace('Bearer ', '')
                user_response = db.auth.get_user(token)
                if user_response.user:
                    user_id = user_response.user.id
                    logger.info(f"Authenticated user: {user_id}")
                else:
                    logger.warning("Invalid token provided")
            except Exception as token_error:
                logger.warning(f"Token validation error: {token_error}")
        
        # If no valid user found, reject the request
        if not user_id:
            raise HTTPException(
                status_code=401, 
                detail="Authentication required. Please login to save diet calculations."
            )
        
        calculation_data = {
            'user_id': user_id,
            'fish_selections': diet_request.fish_selections,
            'total_portion': diet_request.total_portion,
            # Optional range string like '24-40'
            **({'total_portion_range': diet_request.total_portion_range} if diet_request.total_portion_range else {}),
            'portion_details': diet_request.portion_details,
            'date_calculated': datetime.utcnow().isoformat(),
            'saved_plan': 'free'
        }
        
        # Add optional fields only if they have values
        if diet_request.compatibility_issues:
            calculation_data['compatibility_issues'] = diet_request.compatibility_issues
        if diet_request.feeding_notes:
            calculation_data['feeding_notes'] = diet_request.feeding_notes
        
        # First check if table exists by trying a simple query
        try:
            db.table('diet_calculations').select('id').limit(1).execute()
        except Exception as table_error:
            logger.error(f"Table 'diet_calculations' may not exist: {table_error}")
            return {
                "success": False,
                "message": "Database table not found. Please create the diet_calculations table first.",
                "error": "table_not_found"
            }
        
        response = db.table('diet_calculations').insert(calculation_data).execute()
        
        if response.data and len(response.data) > 0:
            return {
                "success": True,
                "calculation_id": response.data[0]['id'],
                "message": "Diet calculation saved successfully"
            }
        else:
            logger.error(f"Insert response: {response}")
            raise HTTPException(status_code=500, detail="Failed to save diet calculation - no data returned")
            
    except Exception as e:
        logger.error(f"Error saving diet calculation: {str(e)}")
        if calculation_data:
            logger.error(f"Calculation data: {calculation_data}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Error saving diet calculation: {str(e)}")

class CompatibilityRequest(BaseModel):
    fish_names: List[str]

@app.post("/check_compatibility")
async def check_fish_compatibility(
    request: CompatibilityRequest,
    db: Client = Depends(get_supabase_client)
):
    """Check compatibility between multiple fish species"""
    try:
        fish_names = request.fish_names
        
        if len(fish_names) < 2:
            return {"compatible": True, "reason": "Single fish species"}
        
        # Get fish data from database
        fish_data = {}
        for fish_name in fish_names:
            response = db.table('fish_species').select('*').ilike('common_name', fish_name).execute()
            if response.data:
                fish_data[fish_name] = response.data[0]
            else:
                return {
                    "compatible": False, 
                    "reason": f"Fish '{fish_name}' not found in database"
                }
        
        # Check pairwise compatibility
        fish_list = list(fish_data.values())
        for i in range(len(fish_list)):
            for j in range(i + 1, len(fish_list)):
                fish1, fish2 = fish_list[i], fish_list[j]
                
                # Check if same species can coexist
                if fish1['common_name'].lower() == fish2['common_name'].lower():
                    can_coexist, reason = can_same_species_coexist(fish1['common_name'], fish1)
                    if not can_coexist:
                        return {"compatible": False, "reason": reason}
                else:
                    # Check different species compatibility
                    compatible, reasons = check_pairwise_compatibility(fish1, fish2)
                    if not compatible:
                        return {
                            "compatible": False,
                            "reason": f"{fish1['common_name']} and {fish2['common_name']} are not compatible: {'; '.join(reasons)}"
                        }
        
        return {"compatible": True, "reason": "All fish are compatible"}
        
    except Exception as e:
        logger.error(f"Error checking compatibility: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to check compatibility: {str(e)}")

# Note: Diet calculation is now handled client-side using OpenAI service
# The /calculate_diet endpoint has been removed as diet portions are generated
# using OpenAI's generateCareRecommendations function in the Flutter app