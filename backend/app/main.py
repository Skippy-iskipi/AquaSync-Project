from fastapi import FastAPI, Depends, HTTPException, Request, status, WebSocket, WebSocketDisconnect, File, UploadFile, Form, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import time
import pandas as pd
import joblib
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
import shutil
import asyncio
import torchvision.transforms.functional as TF
import json
import traceback
from datetime import datetime
import tempfile
import yaml
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import confusion_matrix
import tensorflow as tf
import uuid
import base64
from io import BytesIO
import requests
from bs4 import BeautifulSoup
import aiohttp
import lxml
import re
import urllib.parse
from sqlalchemy.orm import Session  # Add this import
from app.database import get_db    # Add this import
from app.models.image_dataset import ImageDataset  # Add this import

from .supabase_config import get_supabase_client, verify_supabase_connection
from .models import FishSpecies
from .routes.fish_images import router as fish_images_router
from .routes.admin_fish_images import router as admin_fish_images_router
from .routes.model_management import router as model_management_router
from .models.trained_model import TrainedModel
from .supabase_config import get_supabase_client, verify_supabase_connection
from supabase import Client

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# WebSocket connection manager for training logs
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.training_logs: List[Dict[str, Any]] = []
        self.current_progress: Dict[str, Any] = {
            "status": "idle",
            "progress": 0,
            "current_epoch": 0,
            "total_epochs": 0,
            "train_accuracy": 0,
            "val_accuracy": 0,
            "train_loss": 0,
            "val_loss": 0
        }
    
    async def broadcast_log(self, log: str):
        """Send a log message to all connected clients"""
        # Store the log
        log_entry = {"type": "log", "message": log, "timestamp": time.time()}
        self.training_logs.append(log_entry)
        
        # Limit the number of stored logs to prevent memory issues
        if len(self.training_logs) > 1000:
            self.training_logs = self.training_logs[-1000:]
        
        # Broadcast to all connected clients
        await self._broadcast(log_entry)
    
    async def broadcast_progress(self, progress_data: Dict[str, Any]):
        """Update and broadcast training progress"""
        # Update the current progress
        self.current_progress.update(progress_data)
        
        # Create the message
        message = {"type": "progress", "data": self.current_progress, "timestamp": time.time()}
        
        # Broadcast to all connected clients
        await self._broadcast(message)
    
    async def broadcast_epoch_summary(self, epoch_data: Dict[str, Any]):
        """Broadcast epoch summary data"""
        # Create the message
        message = {"type": "epoch_summary", "data": epoch_data, "timestamp": time.time()}
        
        # Broadcast to all connected clients
        await self._broadcast(message)
    
    async def _broadcast(self, message: Dict[str, Any]):
        """Helper method to broadcast a message to all connected clients"""
        # Create a copy of active_connections to avoid modification during iteration
        connections = self.active_connections.copy()
        
        # Track connections to remove
        to_remove = []
        
        # Send to all connections
        for connection in connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.error(f"Error sending message to client: {str(e)}")
                to_remove.append(connection)
        
        # Remove any failed connections
        for connection in to_remove:
            if connection in self.active_connections:
                self.active_connections.remove(connection)
                logger.info(f"Removed dead connection, {len(self.active_connections)} remaining")


# Create the connection manager instance
training_log_manager = ConnectionManager()

# Helper function to determine if a fish species can coexist with itself
def can_same_species_coexist(fish_name, fish_info):
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
    temperament = fish_info.temperament.lower() if fish_info.temperament else ""
    behavior = fish_info.social_behavior.lower() if fish_info.social_behavior else ""
    
    # List of fish that cannot coexist with their own species
    incompatible_species = [
        "betta", "siamese fighting fish", "paradise fish", 
        "dwarf gourami", "honey gourami", 
        "flowerhorn", "wolf cichlid", "oscar", "jaguar cichlid",
        "rainbow shark", "red tail shark", "pearl gourami"
    ]
    
    # Check for known incompatible species
    for species in incompatible_species:
        if species in fish_name_lower:
            return False, f"{fish_name} are known to be aggressive/territorial with their own kind"
    
    # Check temperament
    if "aggressive" in temperament or "territorial" in temperament:
        return False, f"{fish_name} have an aggressive temperament and may fight with each other"
    
    # Check social behavior
    if behavior:
        if "solitary" in behavior or "territorial" in behavior:
            return False, f"{fish_name} prefer to live solitary or are territorial"
    
    # Default to compatibility for schooling/community fish
    return True, f"{fish_name} can live together in groups"

app = FastAPI(
    title="AquaSync API",
    description="API for fish species identification, compatibility, and aquarium management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

@app.on_event("startup")
async def delayed_model_loading():
    import logging
    logging.info("🔥 Delaying model loading until after server binds port")
    # Example: Download and load models here
    from pathlib import Path
    import requests

    # Download EfficientNet model if not present
    efficientnet_url = "https://rdiwfttfxxpenrcxyfuv.supabase.co/storage/v1/object/public/models/efficientnet_b3_fish_classifier.pth"
    efficientnet_path = "app/models/trained_models/efficientnet_b3_fish_classifier.pth"
    if not Path(efficientnet_path).exists():
        r = requests.get(efficientnet_url, stream=True)
        with open(efficientnet_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

    # Download YOLO model if not present
    yolo_url = "https://rdiwfttfxxpenrcxyfuv.supabase.co/storage/v1/object/public/models/yolov8n.pt"
    yolo_path = "app/models/trained_models/yolov8n.pt"
    if not Path(yolo_path).exists():
        r = requests.get(yolo_url, stream=True)
        with open(yolo_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

    # Optionally, load models into memory here (not recommended if memory is tight)
    # from ultralytics import YOLO
    # yolo_model = YOLO(yolo_path)
    # import torch
    # classifier_model = torch.load(efficientnet_path)

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
app.include_router(admin_fish_images_router)
app.include_router(model_management_router)

# Enable CORS - with explicit configuration for WebSocket support
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,  # Allow credentials
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
    expose_headers=["*"],  # Expose all headers
)

@app.websocket("/ws/training-logs")
async def websocket_training_logs(websocket: WebSocket):
    # Log connection attempt
    client = f"{websocket.client.host}:{websocket.client.port}"
    logger.info(f"WebSocket connection attempt from {client}")
    
    try:
        # Accept the connection
        await websocket.accept()
        logger.info(f"WebSocket connection accepted from {client}")
        
        # Add to active connections
        training_log_manager.active_connections.append(websocket)
        
        # Send current status immediately
        try:
            await websocket.send_json({
                "type": "status",
                "message": "Connected to training server",
                "data": training_log_manager.current_progress
            })
        except Exception as e:
            logger.error(f"Error sending initial status: {str(e)}")
        
        # Send initial logs if any exist
        if training_log_manager.training_logs:
            logger.info(f"Sending {len(training_log_manager.training_logs)} existing logs to new client")
            for log in training_log_manager.training_logs:
                try:
                    await websocket.send_json(log)
                except Exception as e:
                    logger.error(f"Error sending log: {str(e)}")
                    break
        
        # Keep the connection alive and handle messages
        while True:
            try:
                # Wait for any message from the client with a 30 second timeout
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                
                if data == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
                elif data == "clear_logs":
                    training_log_manager.training_logs = []
                    await websocket.send_json({"type": "status", "message": "Logs cleared"})
            except asyncio.TimeoutError:
                try:
                    # Send a ping to keep the connection alive
                    await websocket.send_json({"type": "ping", "timestamp": time.time()})
                except Exception as e:
                    logger.error(f"Error sending ping: {str(e)}")
                    break
            except WebSocketDisconnect as e:
                logger.info(f"WebSocket disconnected from {client} with code {e.code}")
                break
            except Exception as e:
                logger.error(f"WebSocket error: {str(e)}")
                break
                
    except WebSocketDisconnect as e:
        logger.info(f"WebSocket disconnected from {client} with code {e.code}")
    except Exception as e:
        logger.error(f"WebSocket error: {str(e)}")
    finally:
        if websocket in training_log_manager.active_connections:
            training_log_manager.active_connections.remove(websocket)
            logger.info(f"Removed connection, {len(training_log_manager.active_connections)} remaining")

# Load trained models and encoders
try:
    le_temperament = joblib.load("app/trained_models/encoder_temperament.pkl")
    le_diet = joblib.load("app/trained_models/encoder_diet.pkl")
    le_water = joblib.load("app/trained_models/encoder_water_type.pkl")
    compatibility_model = joblib.load("app/trained_models/random_forest_fish_compatibility.pkl")
    logger.info("Successfully loaded all models and encoders")
except Exception as e:
    logger.error(f"Error loading models or encoders: {str(e)}")
    # Initialize empty encoders if loading fails
    le_temperament = None
    le_diet = None
    le_water = None
    compatibility_model = None

# Initialize empty DataFrames
fish_df = pd.DataFrame()
fish_df_original = pd.DataFrame()

# Get initial DataFrame and create encoded version
try:
    # Get data from database using Supabase client
    supabase = get_supabase_client()
    response = supabase.table('fish_species').select('*').execute()
    fish_list = response.data
    
    if not fish_list:
        logger.warning("No fish data found in database")
        fish_list = []
    
    # Convert to DataFrame
    fish_data = []
    for fish in fish_list:
        try:
            fish_dict = {
                'temperament': fish.get('temperament'),
                'diet': fish.get('diet'),
                'water_type': fish.get('water_type'),
                'common_name': fish.get('common_name'),
                'scientific_name': fish.get('scientific_name'),
                'max_size': fish.get('max_size_(cm)'),
                'temperature_range': fish.get('temperature_range_{c}') or fish.get('temperature_range_c') or fish.get('temperature_range') or "Unknown",
                'ph_range': fish.get('ph_range'),
                'habitat_type': fish.get('habitat_type'),
                'social_behavior': fish.get('social_behavior'),
                'tank_level': fish.get('tank_level'),
                'minimum_tank_size': fish.get('minimum_tank_size_l'),
                'compatibility_notes': fish.get('compatibility_notes'),
                'lifespan': fish.get('lifespan'),
                'care_level': fish.get('care_level'),
                'preferred_food': fish.get('preferred_food')
            }
            fish_data.append(fish_dict)
        except Exception as e:
            logger.error(f"Error processing fish data: {str(e)}")
            continue
    
    if fish_data:
        fish_df = pd.DataFrame(fish_data)
        fish_df_original = fish_df.copy()
        
        # Only attempt encoding if we have data and encoders
        if not fish_df.empty and all(encoder is not None for encoder in [le_temperament, le_diet, le_water]):
            required_columns = ["temperament", "diet", "water_type"]
            for col, encoder in zip(required_columns, [le_temperament, le_diet, le_water]):
                if col in fish_df.columns and not fish_df[col].isna().all():
                    try:
                        fish_df[col] = encoder.transform(fish_df[col])
                    except Exception as e:
                        logger.error(f"Error encoding column '{col}': {str(e)}")
                else:
                    logger.warning(f"Column '{col}' not found or empty in fish_df. Skipping encoding.")
        
        logger.info("Successfully loaded and processed fish data from database")
    else:
        logger.warning("No valid fish data to process")
        
except Exception as e:
    logger.error(f"Error loading fish data from database: {str(e)}")
    # Keep empty DataFrames if database load fails
    fish_df = pd.DataFrame()
    fish_df_original = pd.DataFrame()

# Dynamically get class names from fish_species table (not fish_images_dataset)
try:
    supabase = get_supabase_client()
    response = supabase.table('fish_species').select('common_name').execute()
    # Get unique class names (case-insensitive, sorted)
    class_names = sorted(set(fish['common_name'] for fish in response.data if fish.get('common_name')))
    logger.info(f"Successfully loaded {len(class_names)} class names from fish_species table.")
except Exception as e:
    logger.error(f"Error loading class names from fish_species table: {str(e)}")
    class_names = []

if not class_names:
    logger.error("class_names is empty! Cannot proceed with prediction. Check your fish_species table.")
    raise RuntimeError("class_names is empty! Cannot proceed with prediction. Check your fish_species table.")

# Mapping: class_idx -> Common Name
idx_to_common_name = {i: class_names[i] for i in range(len(class_names))}

# Load classifier model and setup
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Create model with the same architecture as in train_cnn.py
def create_classifier_model(num_classes):
    """Create a simple EfficientNet model that avoids matrix multiplication issues"""
    # Load pretrained model
    model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
    
    # Replace only the final linear layer with a new one
    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, num_classes)
    
    # Keep the model simple - don't modify the architecture
    return model

def load_classifier_model():
    """Load the classifier model with proper error handling and fallbacks"""
    global class_names
    
    # Log available CUDA devices
    if torch.cuda.is_available():
        logger.info(f"CUDA is available with {torch.cuda.device_count()} devices:")
        for i in range(torch.cuda.device_count()):
            logger.info(f"  Device {i}: {torch.cuda.get_device_name(i)}")
    else:
        logger.info("CUDA is not available, using CPU")
    
    # Get the active CNN model from database if available, otherwise use default
    model_path = "app/models/trained_models/efficientnet_b3_fish_classifier.pth"
    
    try:
        with next(get_supabase_client()) as db:
            active_model = db.query(TrainedModel).filter(
                TrainedModel.model_type == "cnn",
                TrainedModel.is_active == True
            ).first()
            
            if active_model:
                model_path = active_model.file_path
                logger.info(f"Loading active CNN model: {model_path} (version: {active_model.version})")
            else:
                logger.info(f"No active model found in database. Using default model: {model_path}")
    except Exception as e:
        logger.error(f"Database error when loading model: {str(e)}")
    
    # Try multiple approaches to load the model
    try:
        # Approach 1: Try loading from checkpoint (most reliable)
        checkpoint_path = model_path.replace('.pth', '_checkpoint.pth')
        if os.path.exists(checkpoint_path):
            logger.info(f"Found checkpoint at {checkpoint_path}, loading from it")
            checkpoint = torch.load(checkpoint_path, map_location=device)
            
            # Get number of classes from checkpoint or fall back to class_names
            num_classes = checkpoint.get('num_classes', len(class_names))
            logger.info(f"Creating model with {num_classes} classes from checkpoint")
            
            # Create a simple model - don't change the default classifier structure
            model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
            in_features = model.classifier[1].in_features
            model.classifier[1] = nn.Linear(in_features, num_classes)
            
            # Load the state dict if possible, but don't force it
            try:
                if 'model_state_dict' in checkpoint:
                    model.load_state_dict(checkpoint['model_state_dict'], strict=False)
                else:
                    model.load_state_dict(checkpoint, strict=False)
                logger.info("Loaded weights from checkpoint (non-strict)")
            except Exception as e:
                logger.warning(f"Could not load weights from checkpoint: {str(e)}")
                logger.info("Using model with pretrained backbone only")
                
            return model.to(device)
        
        # Approach 2: Try loading state dict directly
        elif os.path.exists(model_path):
            logger.info(f"Loading model from: {model_path}")
            
            # Create a simple model - don't modify the classifier architecture
            model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
            in_features = model.classifier[1].in_features
            model.classifier[1] = nn.Linear(in_features, len(class_names))
            
            try:
                # Try to load the state dict, but don't crash if it fails
                model.load_state_dict(torch.load(model_path, map_location=device), strict=False)
                logger.info("Successfully loaded model weights (non-strict)")
            except Exception as e:
                logger.warning(f"Error loading model weights: {str(e)}")
                logger.info("Using initialized model with pretrained backbone only")
                
            return model.to(device)
        
        # Approach 3: Fall back to a default model
        else:
            logger.warning(f"Model file not found: {model_path}, using default model")
            model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
            in_features = model.classifier[1].in_features
            model.classifier[1] = nn.Linear(in_features, len(class_names))
            return model.to(device)
            
    except Exception as e:
        logger.error(f"Error during model loading: {str(e)}")
        logger.error(traceback.format_exc())
        
        # Final fallback - use the most basic model
        logger.warning("Using fallback model with standard architecture")
        model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
        in_features = model.classifier[1].in_features
        model.classifier[1] = nn.Linear(in_features, len(class_names))
        return model.to(device)

# Log available CUDA devices
if torch.cuda.is_available():
    logger.info(f"CUDA is available with {torch.cuda.device_count()} devices:")
    for i in range(torch.cuda.device_count()):
        logger.info(f"  Device {i}: {torch.cuda.get_device_name(i)}")
else:
    logger.info("CUDA is not available, using CPU")

# Load the classifier model
classifier_model = load_classifier_model()
classifier_model.eval()

# Preprocessing pipeline for classifier
transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# Function to preprocess images consistently between training and inference
def preprocess_fish_image(image, augment=False):
    """Preprocess fish images consistently.
    Args:
        image: PIL Image to preprocess
        augment: Whether to apply augmentation (only during training)
    Returns:
        Preprocessed tensor ready for the model
    """
    # Convert PIL Image to numpy array
    img_array = np.array(image)
    # Normalize to [0,1]
    img_array = img_array.astype('float32') / 255.0
    # Convert to tensor
    return torch.from_numpy(img_array).permute(2, 0, 1)  # Convert to C,H,W format

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE_MB = 5

# Request schema for compatibility checking
class FishGroup(BaseModel):
    fish_names: List[str]

class FishPair(BaseModel):
    fish1: str
    fish2: str

# Load the YOLO model
yolo_model = YOLO("yolov8n.pt") 

@app.post("/predict", 
    summary="Identify fish species from an image",
    description="""
    Upload an image to identify the fish species. The API will:
    1. Use YOLOv8 to detect fish in the image
    2. Crop the detected fish and classify it using the CNN model
    3. Return detailed information about the identified species
    
    Supported image formats: JPG, JPEG, PNG
    Maximum file size: 5 MB
    """,
    response_description="Fish species identification details with confidence scores"
)
async def predict(
    file: UploadFile = File(..., description="Image file containing a fish to identify"),
    db: Client = Depends(get_supabase_client)
):
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
        # First, use YOLO to detect fish
        results = yolo_model(image)
        
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
        
        # Verify the cropped fish image is reasonable (not too small)
        if fish_image.width < 30 or fish_image.height < 30:
            logger.warning(f"Detected fish region is too small: {fish_image.width}x{fish_image.height}")
            # Try with the whole image if the cropped region is too small
            fish_image = image
            logger.info("Using full image instead of small detection")
        
        # Save extracted fish for debugging (optional)
        try:
            debug_dir = "app/debug"
            os.makedirs(debug_dir, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            debug_path = os.path.join(debug_dir, f"fish_crop_{timestamp}.jpg")
            fish_image.save(debug_path)
            logger.info(f"Saved debug crop to {debug_path}")
        except Exception as e:
            logger.warning(f"Could not save debug image: {str(e)}")
            
        # Apply preprocessing to enhance the fish features (optional)
        # Increase contrast slightly to make features more prominent
        enhanced_image = TF.adjust_contrast(fish_image, 1.2)
        fish_image = enhanced_image  # Use the enhanced image
        
        # Verify that the classifier model is properly initialized
        global classifier_model  # Moved global declaration to the beginning
        try:
            # Test with a dummy input to catch shape issues early
            dummy_input = transform(fish_image).unsqueeze(0).to(device)
            classifier_model.eval()
            with torch.no_grad():
                _ = classifier_model(dummy_input)
        except Exception as e:
            logger.error(f"Error with classifier model: {str(e)}. Attempting to reinitialize...")
            
            # Define default model path
            model_path = "app/models/trained_models/efficientnet_b3_fish_classifier.pth"
            
            try:
                # Try to load from checkpoint
                checkpoint_path = model_path.replace('.pth', '_checkpoint.pth')
                if os.path.exists(checkpoint_path):
                    checkpoint = torch.load(checkpoint_path, map_location=device)
                    num_classes = checkpoint.get('num_classes', len(class_names))
                    logger.info(f"Loading from checkpoint with {num_classes} classes")
                    
                    # Create a completely new simple model with default EfficientNet
                    # that avoids shape mismatches by using only a single linear layer
                    model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
                    in_features = model.classifier[1].in_features
                    
                    # Just replace the final linear layer - don't change the classifier structure
                    model.classifier[1] = nn.Linear(in_features, num_classes)
                    
                    # Don't even try to load weights - just use the pretrained backbone
                    classifier_model = model.to(device)
                    classifier_model.eval()
                else:
                    # Fallback to a new model
                    model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
                    in_features = model.classifier[1].in_features
                    model.classifier[1] = nn.Linear(in_features, len(class_names))
                    classifier_model = model.to(device)
                    classifier_model.eval()
                
                # Test with dummy input to verify there are no shape issues
                with torch.no_grad():
                    _ = classifier_model(dummy_input)
                logger.info("Successfully reinitialized the model with a simplified architecture")
            except Exception as e2:
                logger.error(f"Error reinitializing model: {str(e2)}")
                return JSONResponse(
                    status_code=500,
                    content={"detail": f"Error initializing classification model: {str(e2)}"}
                )
        
        # Improved test-time augmentation
        with torch.no_grad():
            # Prepare several variants
            variants = [
                transform(fish_image),  # Standard preprocessing
                transform(TF.hflip(fish_image)),  # Horizontal flip
                transform(TF.resize(TF.center_crop(fish_image, int(min(fish_image.size) * 0.8)), fish_image.size)),  # Center crop
                transform(TF.adjust_brightness(fish_image, 1.2)),  # Brighter
                transform(TF.adjust_brightness(fish_image, 0.8)),  # Darker
            ]
            
            # Batch all variants
            batch = torch.stack(variants).to(device)
            
            try:
                # Forward pass
                outputs = classifier_model(batch)
                
                # Average predictions
                avg_output = outputs.mean(dim=0)
                
                # Apply temperature scaling for sharper probabilities (temperature < 1 increases confidence)
                temperature = 0.4  # More aggressive temperature scaling to increase confidence
                scaled_output = avg_output / temperature
                
                # Get class probabilities
                probabilities = torch.nn.functional.softmax(scaled_output, dim=0)
                
                # Get top prediction
                confidence, pred_idx = torch.max(probabilities, 0)
                class_idx = pred_idx.item()
                score = confidence.item()
                
                # Log top predictions for debugging
                top5_values, top5_indices = torch.topk(probabilities, min(5, len(class_names)))
                logger.info(f"Top 5 predictions: {[idx_to_common_name[idx.item()] for idx in top5_indices]}")
                logger.info(f"Top 5 confidences: {[f'{val.item():.4f}' for val in top5_values]}")
                logger.info(f"Using temperature = {temperature} for confidence scaling")
                logger.info(f"class_names: {class_names}")
                logger.info(f"idx_to_common_name: {idx_to_common_name}")
                logger.info(f"Model output classes: {outputs.shape[-1]}")
            except Exception as e:
                logger.error(f"Error during prediction: {str(e)}")
                # Try with a single image to avoid potential batch issues
                try:
                    logger.info("Falling back to single image prediction...")
                    single_input = transform(fish_image).unsqueeze(0).to(device)
                    outputs = classifier_model(single_input)
                    
                    # Apply the same temperature scaling here
                    temperature = 0.4  # More aggressive temperature scaling to increase confidence
                    scaled_output = outputs[0] / temperature
                    
                    probabilities = torch.nn.functional.softmax(scaled_output, dim=0)
                    confidence, pred_idx = torch.max(probabilities, 0)
                    class_idx = pred_idx.item()
                    score = confidence.item()
                    
                    # Log top predictions for debugging
                    top5_values, top5_indices = torch.topk(probabilities, min(5, len(class_names)))
                    logger.info(f"Top 5 predictions: {[idx_to_common_name[idx.item()] for idx in top5_indices]}")
                    logger.info(f"Top 5 confidences: {[f'{val.item():.4f}' for val in top5_values]}")
                    logger.info(f"Using temperature = {temperature} for confidence scaling")
                    logger.info(f"class_names: {class_names}")
                    logger.info(f"idx_to_common_name: {idx_to_common_name}")
                    logger.info(f"Model output classes: {outputs.shape[-1]}")
                except Exception as e2:
                    logger.error(f"Error in fallback prediction: {str(e2)}")
                    return JSONResponse(
                        status_code=500,
                        content={"detail": f"Prediction failed: {str(e2)}"}
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

        # Get top 3 predictions for transparency
        top_values, top_indices = torch.topk(probabilities, min(3, len(class_names)))
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
            "temperature_range_c": match.get('temperature_range_(°c)', match.get('temperature_range_c', match.get('temperature_range', 'Unknown'))),
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

@app.post("/predict/enhanced", 
    summary="Identify fish species with enhanced accuracy",
    description="""
    Enhanced version of the fish identification endpoint with improved accuracy.
    Includes test-time augmentation, confidence calibration, and threshold filtering.
    
    Supported image formats: JPG, JPEG, PNG
    Maximum file size: 5 MB
    """,
    response_description="Fish species identification with confidence scoring and alternatives"
)
async def predict_enhanced(
    file: UploadFile = File(..., description="Image file containing a fish to identify"),
    db: Client = Depends(get_supabase_client)
):
    """Enhanced prediction with test-time augmentation and better confidence scoring"""
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
        # First, use YOLO to detect fish
        results = yolo_model(image)
        
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

        # Enhanced test-time augmentation for better predictions
        class_probs = None
        augmentations = [
            # Original image
            lambda img: img,
            # Horizontal flip
            lambda img: TF.hflip(img),
            # Vertical flip
            lambda img: TF.vflip(img),
            # Rotate 15 degrees
            lambda img: TF.rotate(img, 15),
            # Rotate -15 degrees
            lambda img: TF.rotate(img, -15),
            # Adjust brightness +20%
            lambda img: TF.adjust_brightness(img, 1.2),
            # Adjust brightness -20%
            lambda img: TF.adjust_brightness(img, 0.8),
            # Adjust contrast +20%
            lambda img: TF.adjust_contrast(img, 1.2),
            # Center crop (80%) and resize back
            lambda img: TF.resize(TF.center_crop(img, int(min(img.size) * 0.8)), img.size)
        ]
        
        logger.info(f"Performing test-time augmentation with {len(augmentations)} variants")
        
        # Process each augmentation
        with torch.no_grad():
            for i, augment in enumerate(augmentations):
                # Apply the augmentation
                aug_image = augment(fish_image)
                
                # Preprocess and predict
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
        
        # Set a confidence threshold to filter out uncertain predictions
        CONFIDENCE_THRESHOLD = 0.4  # Minimum acceptable confidence
        
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

        # Get top 5 predictions for transparency
        top_values, top_indices = torch.topk(calibrated_probs, min(5, len(class_names)))
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
            "temperature_range_c": match.get('temperature_range_(°c)', match.get('temperature_range_c', match.get('temperature_range', 'Unknown'))),
            "ph_range": match.get('ph_range', 'Unknown'),
            "social_behavior": match.get('social_behavior', 'Unknown'),
            "minimum_tank_size_l": match.get('minimum_tank_size_(l)', match.get('minimum_tank_size_l', 'Unknown')),
            "classification_confidence": round(score, 4),
            "top_predictions": top_predictions
        }

    except Exception as e:
        logger.error(f"Enhanced prediction failed: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Enhanced prediction failed: {str(e)}")

@app.post("/predict/visualize", 
    summary="Get fish classification with visualization",
    description="""
    Similar to the predict endpoint but also returns a heatmap visualization
    showing which parts of the image the model focused on for its prediction.
    
    Supported image formats: JPG, JPEG, PNG
    Maximum file size: 5 MB
    """,
    response_description="Fish species identification with visualization heatmap"
)
async def predict_with_visualization(
    file: UploadFile = File(..., description="Image file containing a fish to identify"),
    db: Client = Depends(get_supabase_client)
):
    """Predict fish species and return visualization heatmap"""
    # First run the standard prediction
    result = await predict(file, db)
    
    # Now generate the CAM visualization
    try:
        contents = await file.file.seek(0)  # Reset file pointer
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        
        # Run YOLO detection
        yolo_results = yolo_model(image)
        
        if len(yolo_results[0].boxes) == 0:
            return JSONResponse(
                status_code=400,
                content={
                    "detail": "No fish detected in the image",
                    "has_fish": False
                }
            )
            
        # Get the best box
        boxes = yolo_results[0].boxes
        confidences = boxes.conf.cpu().numpy()
        best_box_idx = np.argmax(confidences)
        best_box = boxes[best_box_idx]
        
        # Crop the fish
        x1, y1, x2, y2 = map(int, best_box.xyxy[0].cpu().numpy())
        fish_image = image.crop((x1, y1, x2, y2))
        
        # Verify the cropped fish image is reasonable (not too small)
        if fish_image.width < 30 or fish_image.height < 30:
            logger.warning(f"Detected fish region is too small: {fish_image.width}x{fish_image.height}")
            # Try with the whole image if the cropped region is too small
            fish_image = image
            logger.info("Using full image instead of small detection")
        
        # Save extracted fish for debugging (optional)
        try:
            debug_dir = "app/debug"
            os.makedirs(debug_dir, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            debug_path = os.path.join(debug_dir, f"fish_crop_{timestamp}.jpg")
            fish_image.save(debug_path)
            logger.info(f"Saved debug crop to {debug_path}")
        except Exception as e:
            logger.warning(f"Could not save debug image: {str(e)}")
            
        # Apply preprocessing to enhance the fish features (optional)
        # Increase contrast slightly to make features more prominent
        enhanced_image = TF.adjust_contrast(fish_image, 1.2)
        fish_image = enhanced_image  # Use the enhanced image
        
        # Preprocess for the model
        input_tensor = preprocess_fish_image(fish_image).unsqueeze(0).to(device)
        
        # Get the predicted class
        class_name = result["common_name"]
        for i, name in enumerate(class_names):
            if format_classname(name) == class_name:
                class_idx = i
                break
        else:
            # If class not found, use the first class
            class_idx = 0
            
        # Generate the CAM
        cam = generate_cam(classifier_model, input_tensor, class_idx)
        
        if cam is None:
            return {
                **result,
                "visualization_available": False,
                "message": "Could not generate visualization"
            }
            
        # Convert the CAM to a base64 encoded image
        import base64
        import cv2
        import numpy as np
        from io import BytesIO
        
        # Resize fish_image to match CAM
        fish_np = np.array(fish_image)
        resized_fish = cv2.resize(fish_np, (cam.shape[1], cam.shape[0]))
        
        # Convert CAM to heatmap
        heatmap = cv2.applyColorMap(np.uint8(255 * cam), cv2.COLORMAP_JET)
        
        # Overlay heatmap on image
        overlay = cv2.addWeighted(cv2.cvtColor(resized_fish, cv2.COLOR_RGB2BGR), 0.7, heatmap, 0.3, 0)
        
        # Convert to JPG
        _, buffer = cv2.imencode('.jpg', overlay)
        
        # Convert to base64
        base64_img = base64.b64encode(buffer).decode('utf-8')
        
        # Add visualization to the result
        return {
            **result,
            "visualization_available": True,
            "visualization": f"data:image/jpeg;base64,{base64_img}"
        }
        
    except Exception as e:
        logger.error(f"Error generating visualization: {str(e)}")
        logger.error(traceback.format_exc())
        return {
            **result,
            "visualization_available": False,
            "visualization_error": str(e)
        }

@app.get("/fish-list")
async def get_fish_list(db: Client = Depends(get_supabase_client)):
    try:
        response = db.table('fish_species').select('*').execute()
        return response.data
    except Exception as e:
        logger.error(f"Error fetching fish list: {str(e)}")
        raise HTTPException(status_code=500, detail="Error fetching fish list")

@app.get("/fish-image/{fish_name}")
async def get_fish_image(fish_name: str, db: Client = Depends(get_supabase_client)):
    """Get a random image for a specific fish from the fish_images_dataset table using Supabase client."""
    import base64
    import random

    # Fetch all images for the given fish name (case-insensitive)
    response = db.table('fish_images_dataset').select('*').ilike('common_name', fish_name).execute()
    images = response.data if response.data else []

    if not images:
        raise HTTPException(status_code=404, detail=f"No image found for fish: {fish_name}")

    # Pick a random image
    image = random.choice(images)
    image_data = image.get('image_data')
    if not image_data:
        raise HTTPException(status_code=404, detail=f"No image data found for fish: {fish_name}")

    # If image_data is already base64, just return it; otherwise, encode
    if isinstance(image_data, str) and image_data.startswith('data:image'):
        base64_image = image_data
    else:
        # If image_data is bytes or base64 string, encode as base64
        if isinstance(image_data, str):
            # If it's a base64 string (not prefixed), add prefix
            base64_image = f"data:image/jpeg;base64,{image_data}"
        else:
            base64_image = f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"

    return {"image_data": base64_image}

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
    async def fetch_fish_image_base64(fish_name: str) -> str:
        response = db.table('fish_images_dataset').select('*').ilike('common_name', fish_name).execute()
        images = response.data if response.data else []
        if not images:
            return None
        image = random.choice(images)
        image_data = image.get('image_data')
        if not image_data:
            return None
        if isinstance(image_data, str) and image_data.startswith('data:image'):
            return image_data
        elif isinstance(image_data, str):
            return f"data:image/jpeg;base64,{image_data}"
        else:
            return f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"

    try:
        fish_names = payload.fish_names
        if len(fish_names) < 2:
            raise HTTPException(status_code=400, detail="Please provide at least two fish names.")

        logger.info(f"Checking compatibility for fish: {fish_names}")
        pairwise_combinations = list(combinations(fish_names, 2))
        results = []

        for fish1_name, fish2_name in pairwise_combinations:
            logger.info(f"Checking pair: {fish1_name} and {fish2_name}")
            
            # Find fish in database using case-insensitive comparison
            response = db.table('fish_species').select('*').ilike('common_name', fish1_name).execute()
            fish1 = response.data[0] if response.data else None
            response = db.table('fish_species').select('*').ilike('common_name', fish2_name).execute()
            fish2 = response.data[0] if response.data else None
            
            if not fish1:
                raise HTTPException(status_code=404, detail=f"Fish not found: {fish1_name}")
            if not fish2:
                raise HTTPException(status_code=404, detail=f"Fish not found: {fish2_name}")

            # Fetch images for both fish
            fish1_image = await fetch_fish_image_base64(fish1_name)
            fish2_image = await fetch_fish_image_base64(fish2_name)

            try:
                # Special case: Check if the same fish species is compared against itself
                if fish1_name.lower() == fish2_name.lower():
                    can_coexist, reason = can_same_species_coexist(fish1_name, fish1)
                    if not can_coexist:
                        compatibility = "Not Compatible"
                        results.append({
                            "pair": [fish1['common_name'], fish2['common_name']],
                            "compatibility": compatibility,
                            "reasons": [reason],
                            "fish1_image": fish1_image,
                            "fish2_image": fish2_image
                        })
                        continue
                size1 = float(fish1.get('max_size') or fish1.get('max_size_(cm)') or 0)
                size2 = float(fish2.get('max_size') or fish2.get('max_size_(cm)') or 0)
                temp1 = le_temperament.transform([fish1.get('temperament', '')])[0]
                temp2 = le_temperament.transform([fish2.get('temperament', '')])[0]
                feature = pd.DataFrame({
                    'size_diff': [abs(size1 - size2)],
                    'temperament_diff': [abs(temp1 - temp2)],
                    'water_type_match': [1 if fish1.get('water_type') == fish2.get('water_type') else 0],
                    'diet_match': [1 if fish1.get('diet') == fish2.get('diet') else 0]
                })
                prediction = compatibility_model.predict(feature)[0]
                compatibility = "Compatible" if prediction == 1 else "Not Compatible"
                reasons = []
                if compatibility == "Not Compatible":
                    if feature['size_diff'][0] > 5:
                        reasons.append("Size difference may cause issues")
                    if feature['temperament_diff'][0] > 1:
                        reasons.append("Temperament mismatch")
                    if feature['water_type_match'][0] == 0:
                        reasons.append("Water type mismatch")
                    if feature['diet_match'][0] == 0:
                        reasons.append("Dietary requirements differ")
                results.append({
                    "pair": [fish1['common_name'], fish2['common_name']],
                    "compatibility": compatibility,
                    "reasons": reasons if reasons else ["Compatible"],
                    "fish1_image": fish1_image,
                    "fish2_image": fish2_image
                })
            except ValueError as e:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid data for fish pair {fish1_name} and {fish2_name}: {str(e)}"
                )
        return {"results": results}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in check_group_compatibility: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

def parse_range(range_str):
    """Parse a range string (e.g., '6.5-7.5' or '22-28') into min and max values."""
    try:
        parts = range_str.split('-')
        return float(parts[0].strip()), float(parts[1].strip())
    except (ValueError, IndexError):
        return None, None

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

            fish_info = db.query(FishSpecies).filter(FishSpecies.common_name == fish_name).first()
            
            if not fish_info:
                return JSONResponse(
                    status_code=404,
                    content={"error": f"Fish not found: {fish_name}"}
                )
            
            # Parse temperature range
            temp_min, temp_max = parse_range(fish_info.temperature_range_c)
            if temp_min is not None:
                min_temp = max(min_temp, temp_min)
            if temp_max is not None:
                max_temp = min(max_temp, temp_max)

            # Parse pH range
            ph_min, ph_max = parse_range(fish_info.ph_range)
            if ph_min is not None:
                min_ph = max(min_ph, ph_min)
            if ph_max is not None:
                max_ph = min(max_ph, ph_max)

            # Calculate tank volume
            min_tank_size = float(fish_info.minimum_tank_size_l)
            total_volume += min_tank_size * quantity

            # Add fish details to response
            fish_details.append({
                "name": fish_name,
                "quantity": quantity,
                "individual_requirements": {
                    "temperature": fish_info.temperature_range_c,
                    "pH": fish_info.ph_range,
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

        # Round values for better presentation
        min_temp = round(min_temp, 1)
        max_temp = round(max_temp, 1)
        min_ph = round(min_ph, 1)
        max_ph = round(max_ph, 1)
        total_volume = round(total_volume, 1)

        return {
            "requirements": {
                "temperature_range": f"{min_temp}°C - {max_temp}°C",
                "pH_range": f"{min_ph} - {max_ph}",
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
        total_bioload = 0
        fish_details = []
        compatibility_issues = []
        fish_info_map = {}

        # First pass: Get fish information and check compatibility
        for fish_name in fish_selections.keys():
            fish_info = db.query(FishSpecies).filter(FishSpecies.common_name == fish_name).first()
            
            if not fish_info:
                return JSONResponse(
                    status_code=404,
                    content={"error": f"Fish not found: {fish_name}"}
                )
            
            fish_info_map[fish_name] = fish_info
            
            # Parse temperature range
            temp_min, temp_max = parse_range(fish_info.temperature_range_c)
            if temp_min is not None:
                min_temp = max(min_temp, temp_min)
            if temp_max is not None:
                max_temp = min(max_temp, temp_max)

            # Parse pH range
            ph_min, ph_max = parse_range(fish_info.ph_range)
            if ph_min is not None:
                min_ph = max(min_ph, ph_min)
            if ph_max is not None:
                max_ph = min(max_ph, ph_max)

        # Check compatibility between fish pairs
        fish_names = list(fish_selections.keys())
        are_compatible = True
        if len(fish_names) >= 2:
            pairwise_combinations = list(combinations(fish_names, 2))
            
            for fish1_name, fish2_name in pairwise_combinations:
                fish1 = fish_info_map[fish1_name]
                fish2 = fish_info_map[fish2_name]

                # Special case: Handle same-species compatibility issues
                if fish1_name == fish2_name:
                    # Use the helper function to determine compatibility
                    can_coexist, reason = can_same_species_coexist(fish1_name, fish1)
                    
                    if not can_coexist:
                        are_compatible = False
                        compatibility_issues.append({
                            "pair": [fish1_name, fish2_name],
                            "reasons": [reason]
                        })
                        continue  # Skip the regular compatibility check for this pair

                # Transform temperament using encoder
                temp1 = le_temperament.transform([fish1.temperament])[0]
                temp2 = le_temperament.transform([fish2.temperament])[0]

                feature = pd.DataFrame({
                    'size_diff': [abs(float(fish1.max_size_cm) - float(fish2.max_size_cm))],
                    'temperament_diff': [abs(temp1 - temp2)],
                    'water_type_match': [1 if fish1.water_type == fish2.water_type else 0],
                    'diet_match': [1 if fish1.diet == fish2.diet else 0]
                })

                prediction = compatibility_model.predict(feature)[0]
                if prediction == 0:  # Not Compatible
                    are_compatible = False
                    reasons = []
                    if feature['size_diff'][0] > 5:
                        reasons.append("Size difference may cause issues")
                    if feature['temperament_diff'][0] > 1:
                        reasons.append("Temperament mismatch")
                    if feature['water_type_match'][0] == 0:
                        reasons.append("Water type mismatch")
                    if feature['diet_match'][0] == 0:
                        reasons.append("Dietary requirements differ")
                    
                    compatibility_issues.append({
                        "pair": [fish1_name, fish2_name],
                        "reasons": reasons
                    })

        # Calculate optimal fish distribution if compatible
        if are_compatible:
            # Calculate the minimum tank size required per fish
            min_sizes = {
                name: float(info.minimum_tank_size_l)
                for name, info in fish_info_map.items()
            }

            # Calculate maximum fish quantities while maintaining balance
            total_space = tank_volume
            base_quantities = {}
            max_quantities = {}
            
            # Calculate maximum individual quantities first
            for fish_name, min_size in min_sizes.items():
                max_quantities[fish_name] = int(tank_volume / min_size)
            
            # First, allocate minimum quantities (1 for each species)
            for fish_name, min_size in min_sizes.items():
                base_quantities[fish_name] = 1
                total_space -= min_size

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
                min_tank_size = float(fish_info.minimum_tank_size_l)
                fish_bioload = min_tank_size * quantity
                total_bioload += fish_bioload

                fish_details.append({
                    "name": fish_name,
                    "recommended_quantity": quantity,
                    "current_quantity": fish_selections[fish_name],
                    "max_capacity": max_quantities[fish_name],
                    "individual_requirements": {
                        "temperature": fish_info.temperature_range_c,
                        "pH": fish_info.ph_range,
                        "minimum_tank_size": f"{min_tank_size} L"
                    }
                })

        else:
            # If fish are not compatible, calculate individual maximums
            for fish_name in fish_selections.keys():
                fish_info = fish_info_map[fish_name]
                min_tank_size = float(fish_info.minimum_tank_size_l)
                max_fish = int(tank_volume / min_tank_size)
                fish_bioload = min_tank_size * fish_selections[fish_name]
                total_bioload += fish_bioload

                fish_details.append({
                    "name": fish_name,
                    "recommended_quantity": "N/A (Incompatible with other species)",
                    "current_quantity": fish_selections[fish_name],
                    "max_individual_capacity": max_fish,
                    "individual_requirements": {
                        "temperature": fish_info.temperature_range_c,
                        "pH": fish_info.ph_range,
                        "minimum_tank_size": f"{min_tank_size} L"
                    }
                })

        # Round values for better presentation
        min_temp = round(min_temp, 1)
        max_temp = round(max_temp, 1)
        min_ph = round(min_ph, 1)
        max_ph = round(max_ph, 1)

        tank_status = "Adequate"
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
                "temperature_range": f"{min_temp}°C - {max_temp}°C",
                "pH_range": f"{min_ph} - {max_ph}"
            },
            "fish_details": fish_details,
            "compatibility_issues": compatibility_issues
        }

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"error": f"Calculation failed: {str(e)}"}
        )

@app.get("/")
async def root():
    return {
        "message": "AquaSync API is running",
        "services": {
            "compatibility": "/check-group",
            "classifier": "/predict"
        }
    }

@app.get("/api/training-data")
async def get_training_data(db: Client = Depends(get_supabase_client)):
    """Get all fish species with image counts for model training"""
    try:

        
        # Get image counts for each species
        
        # Get counts by dataset type and species
        
        # Create a lookup dictionary for counts
        counts_by_species = {}
        
        # Build the response
        datasets = []

        
        return JSONResponse(content=datasets)
    except Exception as e:
        logger.error(f"Error getting training data from database: {str(e)}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

# Keep the old endpoint for backward compatibility
@app.get("/api/datasets")
async def get_datasets(db: Client = Depends(get_supabase_client)):
    """Redirect to the new training-data endpoint"""
    return await get_training_data(db)

@app.get("/admin/fish-list")
async def get_admin_fish_list(db: Client = Depends(get_supabase_client)):
    """
    Admin endpoint to get all fish data with additional fields.
    """
    try:
        # Get all fish data from the database


        fish_list = []
        
            
        return fish_list
    except Exception as e:
        logger.error(f"Error fetching admin fish list: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/admin/export-fish-species-csv")
async def export_fish_species_csv():
    """Export fish species to a clean CSV file for ML training."""
    try:
        from .import_fish_data import export_fish_species_to_csv
        output_path = export_fish_species_to_csv()
        if output_path:
            return FileResponse(
                path=output_path,
                filename="fish_species_for_ml.csv",
                media_type="text/csv"
            )
        else:
            raise HTTPException(status_code=500, detail="Failed to export fish species to CSV")
    except FileNotFoundError as e:
        logger.error(f"Failed to export fish species to CSV: {str(e)}")
        raise HTTPException(status_code=404, detail="File not found")
    except PermissionError as e:
        logger.error(f"Failed to export fish species to CSV: {str(e)}")
        raise HTTPException(status_code=403, detail="Permission denied")
    except Exception as e:
        logger.error(f"Failed to export fish species to CSV: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to export fish species to CSV: {str(e)}")

class AdminFishCreate(BaseModel):
    common_name: str
    scientific_name: str
    water_type: str
    max_size: float
    temperament: str
    temperature_range: str
    ph_range: str
    habitat_type: str = None
    social_behavior: str = None
    tank_level: str = None
    minimum_tank_size: int = None
    compatibility_notes: str = None
    diet: str = None
    lifespan: str = None
    care_level: str = None
    preferred_food: str = None
    feeding_frequency: str = None

class AdminFishUpdate(BaseModel):
    common_name: str = None
    scientific_name: str = None
    water_type: str = None
    max_size: float = None
    temperament: str = None
    temperature_range: str = None
    ph_range: str = None
    habitat_type: str = None
    social_behavior: str = None
    tank_level: str = None
    minimum_tank_size: int = None
    compatibility_notes: str = None
    diet: str = None
    lifespan: str = None
    care_level: str = None
    preferred_food: str = None
    feeding_frequency: str = None

@app.post("/admin/fish")
async def add_fish(fish: AdminFishCreate, db: Client = Depends(get_supabase_client)):
    """Add a new fish species."""
    try:
        response = db.table('fish_species').insert(fish.dict()).execute()
        return response.data[0]
    except Exception as e:
        logger.error(f"Error adding fish: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error adding fish: {str(e)}")

@app.put("/admin/fish/{fish_id}")
async def update_fish(fish_id: int, fish: AdminFishUpdate, db: Client = Depends(get_supabase_client)):
    """Update an existing fish species."""
    try:
        # Remove None values from the update data
        update_data = {k: v for k, v in fish.dict().items() if v is not None}
        response = db.table('fish_species').update(update_data).eq('id', fish_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Fish not found")
        return response.data[0]
    except Exception as e:
        logger.error(f"Error updating fish: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error updating fish: {str(e)}")

@app.delete("/admin/fish/{fish_id}")
async def delete_fish(fish_id: int, db: Client = Depends(get_supabase_client)):
    """Delete a fish species."""
    try:
        response = db.table('fish_species').delete().eq('id', fish_id).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Fish not found")
        return {"message": "Fish deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting fish: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deleting fish: {str(e)}")

@app.post("/admin/import-fish-species-csv")
async def import_fish_species_csv(file: UploadFile = File(...)):
    """Import/Upsert fish species from a CSV file upload."""
    try:
        # Create a temporary directory if it doesn't exist
        temp_dir = os.path.abspath("app/temp")
        os.makedirs(temp_dir, exist_ok=True)
        
        # Save the uploaded file to a temporary location
        temp_path = os.path.join(temp_dir, file.filename)
        try:
            with open(temp_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            
            # Call the upsert logic
            from .import_fish_data import upsert_fish_species_from_csv
            result = upsert_fish_species_from_csv(temp_path)
            
            # Clean up the temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
            return {
                "message": f"Fish species upserted from CSV: {result['updated']} updated, {result['inserted']} inserted",
                "result": result
            }
        except Exception as e:
            logger.error(f"Error processing CSV file: {str(e)}")
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise HTTPException(
                status_code=500, 
                detail=f"Error processing CSV file: {str(e)}"
            )
    except Exception as e:
        logger.error(f"Failed to import fish species CSV: {str(e)}")
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to import fish species CSV: {str(e)}"
        )

@app.post("/admin/retrain-classifier", 
    summary="Retrain the CNN classifier model",
    description="""
    Retrains the CNN classifier model to improve accuracy.
    This endpoint will:
    1. Use the existing training data
    2. Apply proper class balancing 
    3. Use the improved model architecture
    4. Train with proper test-time augmentation
    
    This operation may take some time depending on the dataset size.
    """,
    response_description="Training status and completion message"
)
async def retrain_classifier(
    background_tasks: BackgroundTasks,
    epochs: int = 100,
    batch_size: int = 8,
    learning_rate: float = 0.0001,
    db: Client = Depends(get_supabase_client)
):
    """Retrain the classifier with balanced class weights, using images from Supabase Storage."""
    import tempfile
    import shutil
    from pathlib import Path
    from .supabase_config import get_supabase_client
    import requests

    try:
        from .models.train_cnn import train_cnn_model
        supabase = get_supabase_client()
        bucket = "fish"
        storage_prefixes = ["fish_images/train/", "fish_images/val/", "fish_images/test/"]

        # Create a temporary directory for training data
        temp_dir = tempfile.mkdtemp(prefix="fish_images_")

        def download_all_images():
            for prefix in storage_prefixes:
                res = supabase.storage.from_(bucket).list(path=prefix, limit=10000)
                for f in res:
                    if f["name"].lower().endswith((".jpg", ".jpeg", ".png")):
                        # Download the image
                        file_path = Path(temp_dir) / prefix / f["name"]
                        file_path.parent.mkdir(parents=True, exist_ok=True)
                        public_url = supabase.storage.from_(bucket).get_public_url(prefix + f["name"])
                        r = requests.get(public_url)
                        if r.status_code == 200:
                            with open(file_path, "wb") as out:
                                out.write(r.content)

        # Download all images before training
        download_all_images()
        data_dir = temp_dir
        model_out_path = "app/models/trained_models/efficientnet_b3_fish_classifier_retrained.pth"

        def train_in_background():
            try:
                accuracy, _ = train_cnn_model(
                    species_name="Fish Classifier",
                    data_dir=data_dir,
                    model_out_path=model_out_path,
                    epochs=epochs,
                    batch_size=batch_size,
                    learning_rate=learning_rate,
                    image_size=224,
                    use_data_augmentation=True,
                    stop_flag_callback=None
                )
                # Create a new model record
                new_model = TrainedModel(
                    model_type="cnn",
                    file_path=model_out_path,
                    version=f"retrained_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                    accuracy=accuracy,
                    parameters=json.dumps({
                        "epochs": epochs,
                        "batch_size": batch_size,
                        "learning_rate": learning_rate,
                        "image_size": 224,
                        "use_data_augmentation": True,
                        "balanced_class_weights": True
                    }),
                    is_active=True,
                    num_classes=len(class_names),
                    training_dataset=data_dir
                )
                # Deactivate all other models
                with next(get_supabase_client()) as session:
                    session.query(TrainedModel).filter(
                        TrainedModel.model_type == "cnn"
                    ).update({"is_active": False})
                    # Save the new model
                    session.add(new_model)
                    session.commit()
                    logger.info(f"Model retraining completed with accuracy: {accuracy}%")
            except Exception as e:
                logger.error(f"Error during retraining: {str(e)}")
                logger.error(traceback.format_exc())
            finally:
                # Clean up the temporary directory
                shutil.rmtree(temp_dir, ignore_errors=True)

        # Schedule the training to run in the background
        background_tasks.add_task(train_in_background)
        return {
            "status": "started",
            "message": "Model retraining has been started in the background. Check the logs for progress."
        }
    except Exception as e:
        logger.error(f"Error setting up model retraining: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error setting up model retraining: {str(e)}")

# Function to create a class activation map (CAM)
def generate_cam(model, image_tensor, class_idx):
    """
    Generate a Class Activation Map to show which regions the model focuses on
    
    Args:
        model: The CNN model
        image_tensor: Input image tensor [1, C, H, W]
        class_idx: Index of the class to generate CAM for
        
    Returns:
        numpy array of the CAM (heatmap)
    """
    try:
        # Set to evaluation mode
        model.eval()
        
        # Get the feature maps from the final convolution layer
        feature_maps = []
        
        def hook_fn(module, input, output):
            feature_maps.append(output)
            
        # Register a hook on the last convolutional layer
        # For EfficientNet, this is in the features module
        last_conv_layer = None
        for module in model.features.modules():
            if isinstance(module, nn.Conv2d):
                last_conv_layer = module
                
        if last_conv_layer is None:
            logger.error("Couldn't find the last convolutional layer for CAM")
            return None
            
        hook = last_conv_layer.register_forward_hook(hook_fn)
        
        # Forward pass to get feature maps
        with torch.no_grad():
            output = model(image_tensor)
            
        # Remove the hook
        hook.remove()
        
        # Get the weights from the classifier for the specified class
        # For EfficientNet, we need to get the weights from the last linear layer
        weights = None
        for module in model.classifier.modules():
            if isinstance(module, nn.Linear) and module.out_features > class_idx:
                weights = module.weight.data[class_idx].cpu().numpy()
                
        if weights is None or not feature_maps:
            logger.error("Couldn't extract weights or feature maps for CAM")
            return None
            
        # Get the feature map from the hook
        feature_map = feature_maps[0][0].cpu().numpy()  # First item in batch
        
        # Create the CAM
        cam = np.zeros(feature_map.shape[1:], dtype=np.float32)
        
        # Weight the channels by the gradients
        for i, w in enumerate(weights):
            if i < feature_map.shape[0]:  # Ensure we don't go out of bounds
                cam += w * feature_map[i]
                
        # Apply ReLU to the CAM
        cam = np.maximum(cam, 0)
        
        # Normalize the CAM
        cam = cam - np.min(cam)
        cam = cam / (np.max(cam) + 1e-7)  # Avoid division by zero
        
        # Resize to the input image size
        input_size = image_tensor.shape[2:]  # H, W
        import cv2
        cam = cv2.resize(cam, (input_size[1], input_size[0]))
        
        return cam
    except Exception as e:
        logger.error(f"Error generating CAM: {str(e)}")
        logger.error(traceback.format_exc())
        return None

fish_df.columns = [col.lower() for col in fish_df.columns]

print("fish_df columns:", fish_df.columns)
print("fish_df head:", fish_df.head())

def format_classname(name):
    """Format the class name to match the database format."""
    return name.replace("_", " ").title()
