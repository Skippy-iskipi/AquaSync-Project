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
from .compatibility_logic import parse_range, get_temperament_score, can_same_species_coexist, check_pairwise_compatibility
from .conditional_compatibility import check_conditional_compatibility
from .enhanced_compatibility_integration import (
    check_enhanced_fish_compatibility, 
    get_compatibility_summary,
    check_same_species_enhanced,
    get_enhanced_tankmate_compatibility_info
)
from .ai_compatibility_generator import ai_generator
from supabase import Client

# Set up logging
logging.basicConfig(level=logging.INFO)

def run_yolo_infer(img):
    """Helper for YOLO inference to use within ThreadPoolExecutor."""
    return yolo_model(img, imgsz=384, device='cpu')
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

# Thread pool for CPU-intensive tasks (keep small but allow parallelism)
executor = ThreadPoolExecutor(max_workers=2)

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

def find_fish_folder(fish_name: str) -> str:
    """Find the fish folder by trying different name variations"""
    from pathlib import Path
    
    base_path = Path(__file__).resolve().parent / "datasets" / "fish_images" / "train"
    
    # Try multiple variants to be resilient to naming differences
    variants = []
    provided = fish_name.strip()
    if provided:
        variants.append(provided)  # Exact match
        variants.append(provided.title())  # Title Case (e.g., betta -> Betta)
        variants.append(provided.lower())  # Lower case (e.g., Betta -> betta)
        # Handle cases like "PeaPuffer" -> "Pea Puffer"
        if ' ' not in provided:
            # Try to insert spaces before capital letters (except the first)
            spaced_version = provided[0] + ''.join([' ' + c if c.isupper() and i > 0 else c for i, c in enumerate(provided[1:])])
            variants.append(spaced_version)
    
    # Try to find a matching folder
    for variant in variants:
        folder_path = base_path / variant
        if folder_path.exists() and folder_path.is_dir():
            return str(folder_path)
    
    # If no exact match, try fuzzy matching
    for folder in base_path.iterdir():
        if folder.is_dir():
            folder_name = folder.name.lower()
            fish_name_lower = fish_name.lower()
            
            # Check if fish name is contained in folder name or vice versa
            if (fish_name_lower in folder_name or 
                folder_name in fish_name_lower or
                fish_name_lower.replace(' ', '') in folder_name.replace(' ', '') or
                folder_name.replace(' ', '') in fish_name_lower.replace(' ', '')):
                return str(folder)
    
    return None

# Compatibility functions are now imported from compatibility_logic and conditional_compatibility modules

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

        with torch.no_grad():
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
        with torch.no_grad():
            model = create_large_scale_model(
                num_classes=num_classes,
                architecture=architecture,
                dropout_rate=0.3,
                device=torch.device('cpu'),
                use_pretrained=False  # avoid downloading torchvision weights during inference
            )

        with torch.no_grad():
            try:
                model.load_state_dict(model_state, strict=True)
                logger.info("Successfully loaded model state_dict from checkpoint")
            except Exception as e:
                logger.warning(f"Strict load failed: {e}. Retrying with strict=False")
                model.load_state_dict(model_state, strict=False)

        # Quantize dynamically to shrink memory on CPU (Linear layers)
        try:
            log_memory_usage("before quantization")
            from torch.ao.quantization import quantize_dynamic
        except Exception:
            # Fallback import path for older torch
            try:
                from torch.quantization import quantize_dynamic  # type: ignore
            except Exception:
                quantize_dynamic = None  # type: ignore

        if quantize_dynamic is not None:
            with torch.no_grad():
                model = quantize_dynamic(model, {nn.Linear}, dtype=torch.qint8)
                logger.info("Applied dynamic quantization to classifier model (Linear -> int8)")
                log_memory_usage("after quantization")

        model.to("cpu").eval()

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

        # Step 1: Prepare YOLO and classifier paths (use disk cache for YOLO)
        storage = get_supabase_client().storage.from_("models")
        try:
            logger.info("Preparing YOLO weights and classifier checkpoint...")
            cache_dir = Path(os.getenv("MODEL_CACHE_DIR", "app/model_cache"))
            cache_dir.mkdir(parents=True, exist_ok=True)
            yolo_cache_path = cache_dir / "yolov8n.pt"

            if not yolo_cache_path.exists() or yolo_cache_path.stat().st_size == 0:
                logger.info("YOLO cache miss. Downloading yolov8n.pt to cache...")
                yolo_bytes = await asyncio.get_event_loop().run_in_executor(
                    executor, download_file_with_retry, storage, "yolov8n.pt"
                )
                with open(yolo_cache_path, "wb") as f:
                    f.write(yolo_bytes)
                # Free memory buffer
                del yolo_bytes
            else:
                logger.info(f"Using cached YOLO weights at {yolo_cache_path}")

            # Resolve local checkpoint path
            base_dir = Path(__file__).resolve().parent
            ckpt_path = base_dir / "models" / "trained_models" / "efficientnet_b3_fish_classifier_checkpoint.pth"
            if not ckpt_path.exists():
                raise FileNotFoundError(f"Checkpoint not found at {ckpt_path}")

            logger.info(f"Using local classifier checkpoint at: {ckpt_path}")
        except Exception as e:
            logger.error(f"Failed to prepare model files: {e}")
            model_load_error = f"Model file error: {e}"
            return
        
        # Step 3: Load models (from cached/local files)
        try:
            # Load models sequentially to reduce peak memory usage
            logger.info("Loading classifier model (sequential)...")
            classifier_loaded = await asyncio.get_event_loop().run_in_executor(
                executor, load_classifier_model_sync, str(ckpt_path)
            )
            classifier_model, class_names = classifier_loaded

            logger.info("Loading YOLO model (sequential)...")
            yolo_loaded = await asyncio.get_event_loop().run_in_executor(
                executor, load_yolo_model_sync, str(yolo_cache_path)
            )
            # assign after successful load
            globals()['yolo_model'] = yolo_loaded
            idx_to_common_name = {i: name for i, name in enumerate(class_names)}
            
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
        # Always clean up memory and clear task ref
        try:
            globals()['model_loading_task'] = None
        except Exception:
            pass
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
    
    # Start model loading in background so they're ready shortly after startup
    logger.info("🚀 Starting model loading in background using cached weights when available...")
    model_loading_task = asyncio.create_task(load_models_background())
    logger.info("🎉 FastAPI startup complete! Models are loading in background.")

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
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(
            executor, lambda: yolo_model(image, imgsz=384, device='cpu')
        )
        
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
    specific: str = Query(default=None, description="Specific image filename to return"),
    debug: bool = False,
    db: Client = Depends(get_supabase_client),
):
    """Return an image for a fish from local dataset folder.

    Looks in backend/app/datasets/fish_images/train/{fish_name}/ folder.
    If 'specific' filename is provided, returns that exact image.
    Otherwise, returns a random image.
    Returns the image file directly as a FileResponse.
    """
    import random
    from pathlib import Path

    try:
        # Find the fish folder using the utility function
        fish_folder = find_fish_folder(fish_name)
        
        if not fish_folder:
            detail = {"message": f"No images found for fish: {fish_name}"}
            if debug:
                detail["searched_path"] = str(Path(__file__).resolve().parent / "datasets" / "fish_images" / "train")
            raise HTTPException(status_code=404, detail=detail)

        # Get list of image files in the folder
        folder_path = Path(fish_folder)
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
        
        image_files = []
        for file_path in folder_path.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in image_extensions:
                image_files.append(file_path)
        
        if not image_files:
            raise HTTPException(status_code=404, detail=f"No image files found in folder for fish: {fish_name}")

        # Select image based on parameters
        if specific:
            # Look for the specific image
            selected_image = folder_path / specific
            if not selected_image.exists():
                raise HTTPException(status_code=404, detail=f"Specific image '{specific}' not found")
        else:
            # Select a random image
            selected_image = random.choice(image_files)
        
        # Return the image file directly
        return FileResponse(
            path=str(selected_image),
            media_type=f"image/{selected_image.suffix.lower().lstrip('.')}",
            filename=selected_image.name
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching fish image from local dataset: {e}")
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
        """Fetch fish image from local dataset and convert to base64"""
        if fish_name in fish_image_cache:
            return fish_image_cache[fish_name]
        
        try:
            import base64
            import random
            from pathlib import Path
            
            # Find the fish folder using the utility function
            fish_folder = find_fish_folder(fish_name)
            
            if not fish_folder:
                logger.warning(f"No local images found for fish: {fish_name}")
                return None

            # Get list of image files in the folder
            folder_path = Path(fish_folder)
            image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
            
            image_files = []
            for file_path in folder_path.iterdir():
                if file_path.is_file() and file_path.suffix.lower() in image_extensions:
                    image_files.append(file_path)
            
            if not image_files:
                logger.warning(f"No image files found in folder for fish: {fish_name}")
                return None

            # Select a random image
            selected_image = random.choice(image_files)
            
            # Read the image file and convert to base64
            with open(selected_image, 'rb') as img_file:
                img_data = img_file.read()
                img_base64 = base64.b64encode(img_data).decode('utf-8')
                
                # Determine MIME type based on file extension
                mime_type = f"image/{selected_image.suffix.lower().lstrip('.')}"
                if mime_type == "image/jpg":
                    mime_type = "image/jpeg"
                
                # Return base64 data URL
                result = f"data:{mime_type};base64,{img_base64}"
                fish_image_cache[fish_name] = result
                return result
                
        except Exception as e:
            logger.warning(f"Error fetching local image for {fish_name}: {e}")
            return None

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

            # Special case: Check if the same fish species is compared against itself
            if fish1_name.lower() == fish2_name.lower():
                is_compatible, reason = check_same_species_enhanced(fish1_name, fish1)
                if not is_compatible:
                    compatibility_level = "incompatible"
                    reasons = [reason]
                    conditions = []
                else:
                    compatibility_level = "compatible"
                    reasons = [reason if reason else "These fish can generally live together in groups."]
                    conditions = []
            else:
                # Use the enhanced compatibility check system
                compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
                
                # Ensure we always have meaningful reasons
                if not reasons:
                    if compatibility_level == "compatible":
                        reasons = ["These fish are compatible based on comprehensive attribute analysis including water parameters, temperament, and behavioral traits."]
                    elif compatibility_level == "conditional":
                        reasons = ["These fish may be compatible under specific conditions."]
                    else:
                        reasons = ["These fish are not recommended to be kept together."]
            
            # Generate standardized result using enhanced system
            result = get_compatibility_summary(
                fish1['common_name'], fish2['common_name'], 
                compatibility_level, reasons, conditions
            )
            
            # Add images
            result["fish1_image"] = fish1_image
            result["fish2_image"] = fish2_image
                
            results.append(result)
            
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

            # Build species-specific rules using enhanced system
            can_coexist, reason_same = check_same_species_enhanced(fish_name, fish_info)
            
            # Get enhanced compatibility info
            compatibility_info = get_enhanced_tankmate_compatibility_info(fish_info)
            
            behavior = str(fish_info.get('social_behavior') or '').lower()
            is_schooling = ('school' in behavior) or ('shoal' in behavior)
            min_group = fish_info.get('schooling_min_number', 6 if is_schooling else 1)
            
            species_rules[fish_name] = {
                "solitary": not can_coexist,
                "reason_same": reason_same,
                "schooling": is_schooling,
                "min_group": min_group,
                "allow_tankmates": compatibility_info.get("allow_tankmates", True),
                "special_requirements": compatibility_info.get("special_requirements", [])
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
                compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
                if compatibility_level == "incompatible":
                    are_compatible = False
                    compatibility_issues.append({
                        "pair": [fish1_name, fish2_name],
                        "compatibility_level": compatibility_level,
                        "reasons": reasons
                    })
                elif compatibility_level == "conditional":
                    # For capacity calculations, treat conditional as compatible but add notes
                    compatibility_issues.append({
                        "pair": [fish1_name, fish2_name],
                        "compatibility_level": compatibility_level,
                        "reasons": reasons,
                        "conditions": conditions
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
                "metadata": {
                    "user_id": user_id
                },
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

class CompatibilityAnalysisRequest(BaseModel):
    fish1_name: str
    fish2_name: str

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
        
        # Check pairwise compatibility using the new conditional system
        fish_list = list(fish_data.values())
        incompatible_pairs = []
        conditional_pairs = []
        
        for i in range(len(fish_list)):
            for j in range(i + 1, len(fish_list)):
                fish1, fish2 = fish_list[i], fish_list[j]
                
                # Check if same species can coexist
                if fish1['common_name'].lower() == fish2['common_name'].lower():
                    can_coexist, reason = check_same_species_enhanced(fish1['common_name'], fish1)
                    if not can_coexist:
                        incompatible_pairs.append({
                            "pair": [fish1['common_name'], fish2['common_name']],
                            "reason": reason,
                            "compatibility_level": "incompatible"
                        })
                else:
                    # Use enhanced compatibility check system
                    compatibility_level, reasons, conditions = check_enhanced_fish_compatibility(fish1, fish2)
                    if compatibility_level == "incompatible":
                        incompatible_pairs.append({
                            "pair": [fish1['common_name'], fish2['common_name']],
                            "reason": '; '.join(reasons) if reasons else "Not compatible based on comprehensive analysis",
                            "compatibility_level": compatibility_level
                        })
                    elif compatibility_level == "conditional":
                        conditional_pairs.append({
                            "pair": [fish1['common_name'], fish2['common_name']],
                            "reasons": reasons if reasons else ["May be compatible under specific conditions"],
                            "conditions": conditions,
                            "compatibility_level": compatibility_level
                        })
        
        if incompatible_pairs:
            return {
                "compatible": False, 
                "reason": f"Incompatible pairs found: {incompatible_pairs[0]['reason']}",
                "incompatible_pairs": incompatible_pairs
            }
        elif conditional_pairs:
            return {
                "compatible": True,
                "conditional": True,
                "reason": "All fish are compatible with conditions",
                "conditional_pairs": conditional_pairs
            }
        else:
            return {"compatible": True, "reason": "All fish are fully compatible"}
        
    except Exception as e:
        logger.error(f"Error checking compatibility: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to check compatibility: {str(e)}")

@app.post("/tankmate-recommendations")
async def get_tankmate_recommendations(
    payload: FishGroup, 
    db: Client = Depends(get_supabase_client)
):
    """Get enhanced tankmate recommendations with compatibility levels for the given fish species"""
    try:
        fish_names = payload.fish_names
        
        if not fish_names:
            return {"recommendations": []}
        
        # Get detailed tankmate recommendations for all provided fish
        all_recommendations = {}
        detailed_recommendations = {}
        
        for fish_name in fish_names:
            try:
                # Query the enhanced tankmate recommendations
                response = db.table('fish_tankmate_recommendations')\
                    .select('*')\
                    .ilike('fish_name', fish_name)\
                    .execute()
                
                if response.data and response.data[0]:
                    fish_data = response.data[0]
                    
                    # Store detailed recommendations for this fish
                    detailed_recommendations[fish_name] = {
                        'fully_compatible': fish_data.get('fully_compatible_tankmates', []),
                        'conditional': fish_data.get('conditional_tankmates', []),
                        'incompatible': fish_data.get('incompatible_tankmates', []),
                        'special_requirements': fish_data.get('special_requirements', []),
                        'care_level': fish_data.get('care_level', ''),
                        'total_recommended': fish_data.get('total_recommended', 0)
                    }
                    
                    # For backward compatibility, combine fully compatible and conditional
                    all_compatible = fish_data.get('fully_compatible_tankmates', []) + \
                                   [item['name'] if isinstance(item, dict) else item 
                                    for item in fish_data.get('conditional_tankmates', [])]
                    
                    if all_recommendations:
                        # Intersection: only fish compatible with ALL provided fish
                        all_recommendations &= set(all_compatible)
                    else:
                        # First fish: start with its recommendations
                        all_recommendations = set(all_compatible)
                
            except Exception as e:
                logger.warning(f"Error getting recommendations for {fish_name}: {e}")
                continue
        
        # Remove the input fish from recommendations
        for fish_name in fish_names:
            all_recommendations.discard(fish_name)
        
        # Convert to sorted list and limit to top 10
        recommendations = sorted(list(all_recommendations))[:10]
        
        return {
            "recommendations": recommendations,
            "total_found": len(recommendations),
            "input_fish": fish_names,
            "detailed_recommendations": detailed_recommendations,
            "compatibility_levels": {
                "fully_compatible": "Fish that can live together without issues",
                "conditional": "Fish that can live together with specific conditions",
                "incompatible": "Fish that should never be kept together"
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting tankmate recommendations: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get tankmate recommendations: {str(e)}")

@app.get("/tankmate-details/{fish_name}")
async def get_tankmate_details(
    fish_name: str,
    db: Client = Depends(get_supabase_client)
):
    """Get detailed tankmate information for a specific fish species"""
    try:
        # Query the enhanced tankmate recommendations
        response = db.table('fish_tankmate_recommendations')\
            .select('*')\
            .ilike('fish_name', fish_name)\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail=f"No tankmate data found for {fish_name}")
        
        fish_data = response.data[0]
        
        return {
            "fish_name": fish_data.get('fish_name'),
            "fully_compatible_tankmates": fish_data.get('fully_compatible_tankmates', []),
            "conditional_tankmates": fish_data.get('conditional_tankmates', []),
            "incompatible_tankmates": fish_data.get('incompatible_tankmates', []),
            "special_requirements": fish_data.get('special_requirements', []),
            "care_level": fish_data.get('care_level', ''),
            "confidence_score": fish_data.get('confidence_score', 0.0),
            "total_fully_compatible": fish_data.get('total_fully_compatible', 0),
            "total_conditional": fish_data.get('total_conditional', 0),
            "total_incompatible": fish_data.get('total_incompatible', 0),
            "total_recommended": fish_data.get('total_recommended', 0),
            "generation_method": fish_data.get('generation_method', ''),
            "calculated_at": fish_data.get('calculated_at', ''),
            "compatibility_summary": {
                "fully_compatible": "Fish that can live together without issues",
                "conditional": "Fish that can live together with specific conditions", 
                "incompatible": "Fish that should never be kept together"
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting tankmate details for {fish_name}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get tankmate details: {str(e)}")

@app.get("/compatibility-matrix/{fish1_name}/{fish2_name}")
async def get_compatibility_matrix(
    fish1_name: str,
    fish2_name: str,
    db: Client = Depends(get_supabase_client)
):
    """Get detailed compatibility information between two specific fish species"""
    try:
        # Query the compatibility matrix
        response = db.table('fish_compatibility_matrix')\
            .select('*')\
            .or_(f"fish1_name.eq.{fish1_name},fish2_name.eq.{fish1_name}")\
            .or_(f"fish1_name.eq.{fish2_name},fish2_name.eq.{fish2_name}")\
            .execute()
        
        if not response.data:
            return {
                "fish1_name": fish1_name,
                "fish2_name": fish2_name,
                "compatibility_level": "unknown",
                "is_compatible": False,
                "compatibility_reasons": ["No compatibility data available"],
                "conditions": [],
                "confidence_score": 0.0
            }
        
        # Find the specific pair
        compatibility_data = None
        for item in response.data:
            if ((item['fish1_name'] == fish1_name and item['fish2_name'] == fish2_name) or
                (item['fish1_name'] == fish2_name and item['fish2_name'] == fish1_name)):
                compatibility_data = item
                break
        
        if not compatibility_data:
            return {
                "fish1_name": fish1_name,
                "fish2_name": fish2_name,
                "compatibility_level": "unknown",
                "is_compatible": False,
                "compatibility_reasons": ["No compatibility data available"],
                "conditions": [],
                "confidence_score": 0.0
            }
        
        return {
            "fish1_name": compatibility_data.get('fish1_name'),
            "fish2_name": compatibility_data.get('fish2_name'),
            "compatibility_level": compatibility_data.get('compatibility_level'),
            "is_compatible": compatibility_data.get('is_compatible'),
            "compatibility_reasons": compatibility_data.get('compatibility_reasons', []),
            "conditions": compatibility_data.get('conditions', []),
            "compatibility_score": compatibility_data.get('compatibility_score', 0.0),
            "confidence_score": compatibility_data.get('confidence_score', 0.0),
            "generation_method": compatibility_data.get('generation_method', ''),
            "calculated_at": compatibility_data.get('calculated_at', '')
        }
        
    except Exception as e:
        logger.error(f"Error getting compatibility matrix for {fish1_name} + {fish2_name}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get compatibility matrix: {str(e)}")

@app.post("/ai-compatibility-analysis")
async def get_ai_compatibility_analysis(
    fish1_name: str,
    fish2_name: str,
    db: Client = Depends(get_supabase_client)
):
    """Get AI-generated compatibility analysis between two fish species"""
    try:
        # Get fish data from database
        fish1_response = db.table('fish_species').select('*').ilike('common_name', fish1_name).execute()
        fish2_response = db.table('fish_species').select('*').ilike('common_name', fish2_name).execute()
        
        # Extract the first result if available
        fish1_data = fish1_response.data[0] if fish1_response.data else None
        fish2_data = fish2_response.data[0] if fish2_response.data else None
        
        if not fish1_data:
            raise HTTPException(status_code=404, detail=f"Fish species '{fish1_name}' not found")
        
        if not fish2_data:
            raise HTTPException(status_code=404, detail=f"Fish species '{fish2_name}' not found")
        
        # Generate AI compatibility analysis
        compatibility_result = await ai_generator.generate_compatibility_requirements(
            fish1_data, fish2_data
        )
        
        return {
            "success": True,
            "data": compatibility_result,
            "ai_generated": compatibility_result.get('ai_generated', False),
            "confidence_score": compatibility_result.get('confidence_score', 0.0),
            "generation_method": compatibility_result.get('generation_method', 'unknown')
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating AI compatibility analysis: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate compatibility analysis: {str(e)}")

@app.get("/ai-fish-requirements/{fish_name}")
async def get_ai_fish_requirements(
    fish_name: str,
    db: Client = Depends(get_supabase_client)
):
    """Get AI-generated care requirements for a specific fish species"""
    try:
        # Get fish data from database
        fish_response = db.table('fish_species').select('*').ilike('common_name', fish_name).maybeSingle()
        
        if not fish_response:
            raise HTTPException(status_code=404, detail=f"Fish species '{fish_name}' not found")
        
        # Generate AI fish requirements
        requirements_result = await ai_generator.generate_fish_specific_requirements(fish_response)
        
        return {
            "success": True,
            "data": requirements_result,
            "ai_generated": requirements_result.get('ai_generated', False),
            "confidence_score": requirements_result.get('confidence_score', 0.0),
            "generation_method": requirements_result.get('generation_method', 'unknown')
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating AI fish requirements: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate fish requirements: {str(e)}")

# Note: Diet calculation is now handled client-side using OpenAI service
# The /calculate_diet endpoint has been removed as diet portions are generated
# using OpenAI's generateCareRecommendations function in the Flutter app

@app.get("/fish-image-base64/{fish_name}")
async def get_fish_image_base64(
    fish_name: str,
    debug: bool = False,
    db: Client = Depends(get_supabase_client),
):
    """Return a random image for a fish as base64 data URL from local dataset folder.

    Looks in backend/app/datasets/fish_images/train/{fish_name}/ folder.
    Returns the image as a base64 data URL for easy frontend consumption.
    """
    import random
    import base64
    from pathlib import Path

    try:
        # Find the fish folder using the utility function
        fish_folder = find_fish_folder(fish_name)
        
        if not fish_folder:
            detail = {"message": f"No images found for fish: {fish_name}"}
            if debug:
                detail["searched_path"] = str(Path(__file__).resolve().parent / "datasets" / "fish_images" / "train")
            raise HTTPException(status_code=404, detail=detail)

        # Get list of image files in the folder
        folder_path = Path(fish_folder)
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
        
        image_files = []
        for file_path in folder_path.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in image_extensions:
                image_files.append(file_path)
        
        if not image_files:
            raise HTTPException(status_code=404, detail=f"No image files found in folder for fish: {fish_name}")

        # Select a random image
        selected_image = random.choice(image_files)
        
        # Read the image file and convert to base64
        with open(selected_image, 'rb') as img_file:
            img_data = img_file.read()
            img_base64 = base64.b64encode(img_data).decode('utf-8')
            
            # Determine MIME type based on file extension
            mime_type = f"image/{selected_image.suffix.lower().lstrip('.')}"
            if mime_type == "image/jpg":
                mime_type = "image/jpeg"
            
            # Return base64 data URL
            data_url = f"data:{mime_type};base64,{img_base64}"
            
            return {
                "data_url": data_url,
                "filename": selected_image.name,
                "mime_type": mime_type,
                "size_bytes": len(img_data),
                "fish_name": fish_name
            }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching fish image from local dataset: {e}")
        raise HTTPException(status_code=500, detail="Error fetching fish image")

@app.get("/fish-images-grid/{fish_name}")
async def get_fish_images_grid(
    fish_name: str,
    count: int = Query(default=4, ge=1, le=10, description="Number of different images to return"),
    debug: bool = False,
    db: Client = Depends(get_supabase_client),
):
    """Return multiple different images for a fish from local dataset folder.

    Looks in backend/app/datasets/fish_images/train/{fish_name}/ folder.
    Returns exactly 'count' different images to ensure variety in the grid.
    """
    import random
    from pathlib import Path

    try:
        # Find the fish folder using the utility function
        fish_folder = find_fish_folder(fish_name)
        
        if not fish_folder:
            detail = {"message": f"No images found for fish: {fish_name}"}
            if debug:
                detail["searched_path"] = str(Path(__file__).resolve().parent / "datasets" / "fish_images" / "train")
            raise HTTPException(status_code=404, detail=detail)

        # Get list of image files in the folder
        folder_path = Path(fish_folder)
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}
        
        image_files = []
        for file_path in folder_path.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in image_extensions:
                image_files.append(file_path)
        
        if not image_files:
            raise HTTPException(status_code=404, detail=f"No image files found in folder for fish: {fish_name}")

        # Ensure we don't request more images than available
        requested_count = min(count, len(image_files))
        
        # Select exactly 'requested_count' different images
        selected_images = random.sample(image_files, requested_count)
        
        # Return the list of selected image files
        return {
            "fish_name": fish_name,
            "total_available": len(image_files),
            "requested_count": count,
            "returned_count": requested_count,
            "images": [
                {
                    "filename": img.name,
                    "url": f"/fish-image/{fish_name}?specific={img.name}",
                    "size_bytes": img.stat().st_size if img.exists() else 0
                }
                for img in selected_images
            ]
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching fish images grid from local dataset: {e}")
        raise HTTPException(status_code=500, detail="Error fetching fish images grid")