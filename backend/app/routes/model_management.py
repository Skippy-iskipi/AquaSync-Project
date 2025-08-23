from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, UploadFile, File, Form
from typing import Optional, Dict, Any, List
from pathlib import Path
import json
import logging
import traceback
import tempfile
import os
import time
from app.supabase_config import get_supabase_client
from supabase import Client

# Global flag to control training process
STOP_TRAINING = False

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/models",
    tags=["model-management"],
)

@router.get("/datasets")
async def get_datasets():
    """Get all available datasets for model training (file system only)"""
    try:
        datasets_dir = Path("app/datasets/fish_images")
        if not datasets_dir.exists():
            return []
        train_dir = datasets_dir / "train"
        if not train_dir.exists() or not train_dir.is_dir():
            return []
        class_dirs = [d for d in train_dir.iterdir() if d.is_dir()]
        datasets = []
        for class_dir in class_dirs:
            train_count = len(list(class_dir.glob("*.jpg")))
            val_dir = datasets_dir / "val" / class_dir.name
            test_dir = datasets_dir / "test" / class_dir.name
            val_count = len(list(val_dir.glob("*.jpg"))) if val_dir.exists() else 0
            test_count = len(list(test_dir.glob("*.jpg"))) if test_dir.exists() else 0
            datasets.append({
                "id": class_dir.name,
                "name": class_dir.name.replace("_", " ").title(),
                "train_count": train_count,
                "val_count": val_count,
                "test_count": test_count,
                "total_count": train_count + val_count + test_count
            })
        return datasets
    except Exception as e:
        logger.error(f"Error fetching datasets: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error fetching datasets: {str(e)}")


@router.post("/train")
async def train_model(
    model_type: str = Form(...),
    learning_rate: float = Form(...),
    epochs: int = Form(...),
    batch_size: int = Form(...),
    model_out_path: Optional[str] = Form(None),
    image_size: Optional[int] = Form(None),
    use_data_augmentation: Optional[bool] = Form(True),
    csv_file: Optional[UploadFile] = File(None),
    # This will capture all selectedSpecies[] form fields
    selected_species: Optional[List[str]] = Form(None),
    db: Client = Depends(get_supabase_client)
):
    """Endpoint to train a model based on its type"""
    try:
        # Import necessary modules directly within this function
        import os
        import shutil
        from pathlib import Path
        
        # Remove any existing stop signal files before starting training
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        if os.path.exists(stop_signal_path):
            try:
                os.remove(stop_signal_path)
                logger.info(f"Removed existing stop signal file at {stop_signal_path}")
            except Exception as e:
                logger.error(f"Error removing existing stop signal file: {str(e)}")
        
        # Create models directory if it doesn't exist
        models_dir = Path("app/models/trained_models")
        models_dir.mkdir(parents=True, exist_ok=True)
        
        # Import CNN training module
        from ..models.train_cnn import train_cnn_model
        from typing import List
        
        # Generate a timestamped model path if not provided
        if not model_out_path:
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            model_out_path = f"app/models/trained_models/{model_type}_{timestamp}.pth"
        
        # Save CSV file if provided
        csv_path = None
        if csv_file:
            csv_path = f"app/datasets/{csv_file.filename}"
            with open(csv_path, "wb") as buffer:
                shutil.copyfileobj(csv_file.file, buffer)
        
        # Define a function to check the stop flag
        def check_stop_flag():
            global STOP_TRAINING
            return STOP_TRAINING
        
        # Train the model based on its type
        if model_type == "cnn":
            # Check if required parameters are provided
            if not model_out_path or not image_size:
                raise HTTPException(
                    status_code=400,
                    detail="Missing required parameters for CNN model training"
                )
            
            # Build a temporary dataset directory by downloading from Supabase Storage bucket 'fish-images'
            import tempfile
            import os
            
            def download_split_from_storage(storage_client: Any, split: str, base_dir: str) -> int:
                """Download a dataset split (train/val/test) from Supabase Storage into base_dir. Returns number of files downloaded."""
                count = 0
                try:
                    # List immediate children under the split (species folders)
                    entries = storage_client.list(split, {"limit": 10000, "offset": 0}) or []
                    for entry in entries:
                        name = entry.get("name")
                        metadata = entry.get("metadata")
                        if not name:
                            continue
                        if metadata is None:
                            # Likely a folder representing species
                            species_dir = name
                            species_files = storage_client.list(f"{split}/{species_dir}", {"limit": 10000, "offset": 0}) or []
                            os.makedirs(os.path.join(base_dir, split, species_dir), exist_ok=True)
                            for f in species_files:
                                file_name = f.get("name")
                                f_meta = f.get("metadata")
                                if not file_name or f_meta is None:
                                    # Skip nested folders
                                    continue
                                remote_path = f"{split}/{species_dir}/{file_name}"
                                try:
                                    data = storage_client.download(remote_path)
                                except Exception as de:
                                    logger.warning(f"Failed to download {remote_path}: {de}")
                                    continue
                                if not data:
                                    continue
                                local_path = os.path.join(base_dir, split, species_dir, file_name)
                                with open(local_path, "wb") as out:
                                    out.write(data)
                                count += 1
                        else:
                            # File directly under split; uncommon, skip or handle if needed
                            logger.warning(f"Found unexpected file under '{split}' root: {name}. Skipping.")
                except Exception as e:
                    logger.error(f"Error listing/downloading split '{split}': {e}")
                return count
            
            with tempfile.TemporaryDirectory() as temp_data_dir:
                # Ensure split directories exist
                for split in ["train", "val", "test"]:
                    os.makedirs(os.path.join(temp_data_dir, split), exist_ok=True)
                
                # Download from Supabase Storage
                try:
                    storage = db.storage.from_("fish-images")
                except Exception as e:
                    logger.error(f"Failed to access Supabase Storage bucket 'fish-images': {e}")
                    raise HTTPException(status_code=500, detail="Could not access dataset storage bucket")
                
                total_downloaded = 0
                for split in ["train", "val", "test"]:
                    downloaded = download_split_from_storage(storage, split, temp_data_dir)
                    logger.info(f"Downloaded {downloaded} files for split '{split}' from storage.")
                    total_downloaded += downloaded
                
                if total_downloaded == 0:
                    raise HTTPException(status_code=400, detail="No images found in 'fish-images' storage bucket. Please upload dataset images.")
                
                # Make sure the stop flag is reset before training
                global STOP_TRAINING
                STOP_TRAINING = False
                
                # Train the CNN model using the temporary directory with stop flag callback
                accuracy, training_logs = train_cnn_model(
                    species_name="All species",
                    data_dir=temp_data_dir,
                    model_out_path=model_out_path,
                    image_size=image_size,
                    batch_size=batch_size,
                    learning_rate=learning_rate,
                    epochs=epochs,
                    use_data_augmentation=use_data_augmentation,
                    stop_flag_callback=check_stop_flag
                )
                
                # Reset stop flag after training
                STOP_TRAINING = False
            
            # Attempt to capture remote storage keys returned by training
            remote_model_key = None
            if isinstance(training_logs, dict):
                remote_model_key = training_logs.get("model_storage_key")
            
            # Determine number of classes by inspecting the 'train' split directories in storage
            try:
                train_entries = db.storage.from_("fish-images").list("train", {"limit": 10000, "offset": 0}) or []
                num_classes = sum(1 for e in train_entries if e.get("metadata") is None)
            except Exception:
                num_classes = None
            
            # Create model record in database using Supabase
            db.table('trained_models').update({"is_active": False}).eq('model_type', model_type).execute()
            
            model_record = {
                "model_type": model_type,
                # Prefer remote storage key if available
                "file_path": remote_model_key or model_out_path,
                "version": Path(model_out_path).stem,
                "accuracy": accuracy,
                "parameters": json.dumps({
                    "learning_rate": learning_rate,
                    "epochs": epochs,
                    "batch_size": batch_size,
                    "image_size": image_size,
                    "use_data_augmentation": use_data_augmentation
                }),
                "num_classes": num_classes,
                "training_dataset": "Supabase Storage: fish-images",
                "is_active": True
            }
            model_result = db.table('trained_models').insert(model_record).execute()
            model_id = model_result.data[0]['id'] if model_result.data else None
            
            return {
                "message": f"{model_type.upper()} model trained successfully",
                "model_id": model_id,
                "file_path": model_record["file_path"],
                "accuracy": accuracy
            }
            
        elif model_type == "yolo":
            # TODO: Implement YOLO training
            raise HTTPException(status_code=501, detail="YOLO training not yet implemented")
            
        elif model_type == "randomForest":
            # TODO: Implement Random Forest training
            raise HTTPException(status_code=501, detail="Random Forest training not yet implemented")
            
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported model type: {model_type}")
            
    except Exception as e:
        logger.error(f"Error training model: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail=f"Failed to train model: {str(e)}"
        )

@router.post("/save")
async def save_model(
    model_type: str,
    model_id: str,
    version: str,
    parameters: Dict[str, Any],
    accuracy: float = 0,
    is_active: bool = True,
    db: Client = Depends(get_supabase_client)
):
    """Save a trained model to the database (Supabase)"""
    try:
        model_path = f"app/models/trained_models/{model_id}"
        if not os.path.exists(model_path):
            logger.error(f"Model file not found at {model_path}")
            raise HTTPException(
                status_code=404, 
                detail="Model file not found. Training may have been stopped before completion."
            )
        # If this model is active, deactivate all other models of the same type
        if is_active:
            db.table('trained_models').update({"is_active": False}).eq('model_type', model_type).execute()
        # Insert the new model
        result = db.table('trained_models').insert({
            "model_type": model_type,
            "file_path": model_path,
            "version": version,
            "accuracy": accuracy,
            "parameters": json.dumps(parameters),
            "is_active": is_active
        }).execute()
        return {"message": "Model saved successfully", "model_id": result.data[0]['id'] if result.data else None}
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Error saving model: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error saving model: {str(e)}")

@router.get("/")
async def get_models(db: Client = Depends(get_supabase_client)):
    """Get all trained models"""
    response = db.table('trained_models').select('*').order('created_at', desc=True).execute()
    return response.data

@router.get("/{model_type}/active")
async def get_active_model(model_type: str, db: Client = Depends(get_supabase_client)):
    """Get the active model for a specific type"""
    response = db.table('trained_models').select('*').eq('model_type', model_type).eq('is_active', True).limit(1).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail=f"No active {model_type} model found")
    return response.data[0]

@router.put("/{model_id}/activate")
async def activate_model(model_id: int, db: Client = Depends(get_supabase_client)):
    """Activate a specific model and deactivate all others of the same type"""
    # Get the model
    response = db.table('trained_models').select('*').eq('id', model_id).limit(1).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Model not found")
    model = response.data[0]
    # Deactivate all other models of the same type
    db.table('trained_models').update({"is_active": False}).eq('model_type', model['model_type']).neq('id', model_id).execute()
    # Activate this model
    db.table('trained_models').update({"is_active": True}).eq('id', model_id).execute()
    return {"message": f"Model {model_id} activated successfully"}

@router.delete("/{model_id}")
async def delete_model(model_id: int, db: Client = Depends(get_supabase_client)):
    """Delete a model from the database and file system"""
    response = db.table('trained_models').select('*').eq('id', model_id).limit(1).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Model not found")
    model = response.data[0]
    # Delete the model file if it exists
    if os.path.exists(model['file_path']):
        os.remove(model['file_path'])
    # Delete from database
    db.table('trained_models').delete().eq('id', model_id).execute()
    return {"message": f"Model {model_id} deleted successfully"}

@router.post("/stop-training")
async def stop_training(model_type: Optional[str] = None):
    """Stop the current model training process (file system only)"""
    try:
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        with open(stop_signal_path, "w") as f:
            f.write(f"STOP=TRUE\nTimestamp={time.time()}\nRequested by user")
        logger.info(f"Created stop signal file at {stop_signal_path}")
        if model_type:
            if model_type == "cnn":
                progress_file = "training_progress/cnn_training_progress.json"
            elif model_type == "yolo":
                progress_file = "training_progress/yolo_training_progress.json"
            elif model_type == "random_forest":
                progress_file = "training_progress/random_forest_training_progress.json"
            else:
                return {
                    "success": False,
                    "error": f"Unknown model type: {model_type}"
                }
            if os.path.exists(progress_file):
                try:
                    with open(progress_file, "r") as f:
                        progress_data = json.load(f)
                    progress_data["status"] = "stopping"
                    progress_data["message"] = "Training is being stopped..."
                    progress_data["timestamp"] = time.time()
                    with open(progress_file, "w") as f:
                        json.dump(progress_data, f)
                    logger.info(f"Updated progress file {progress_file} to stopping status")
                except Exception as e:
                    logger.error(f"Error updating progress file: {str(e)}")
        return {
            "success": True,
            "message": "Stop signal sent to training process"
        }
    except Exception as e:
        logger.error(f"Error stopping training: {str(e)}")
        return {
            "success": False,
            "message": f"Error stopping training: {str(e)}"
        }

@router.get("/training-progress/{model_type}")
async def get_training_progress(model_type: str):
    """Get the current training progress for a specific model type (file system only)"""
    try:
        if model_type == "cnn":
            progress_file = "training_progress/cnn_training_progress.json"
        elif model_type == "yolo":
            progress_file = "training_progress/yolo_training_progress.json"
        elif model_type == "random_forest":
            progress_file = "training_progress/random_forest_training_progress.json"
        else:
            return {
                "success": False,
                "error": f"Unknown model type: {model_type}"
            }
        if not os.path.exists(progress_file):
            os.makedirs(os.path.dirname(progress_file), exist_ok=True)
            with open(progress_file, "w") as f:
                json.dump({
                    "status": "idle",
                    "progress": 0,
                    "timestamp": time.time()
                }, f)
        with open(progress_file, "r") as f:
            progress_data = json.load(f)
        current_time = time.time()
        last_update_time = progress_data.get('timestamp', 0)
        if progress_data.get('status') == 'training' and (current_time - last_update_time) > 10:
            logger.info(f"Training appears inactive (no updates for {current_time - last_update_time:.1f} seconds). Setting status to stopped.")
            progress_data['status'] = 'stopped'
            progress_data['message'] = 'Training stopped due to inactivity'
            with open(progress_file, 'w') as f:
                json.dump(progress_data, f)
            stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
            if not os.path.exists(stop_signal_path):
                with open(stop_signal_path, 'w') as f:
                    f.write(f"FORCE_STOP=TRUE\nStop requested due to inactivity at {time.time()}")
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        if os.path.exists(stop_signal_path):
            current_time = time.time()
            last_log_time = getattr(get_training_progress, 'last_log_time', 0)
            if current_time - last_log_time > 60:
                logger.info(f"Found stop signal file at {stop_signal_path}, returning stopped status")
                get_training_progress.last_log_time = current_time
            if progress_data.get('status') != 'stopped':
                progress_data['status'] = "stopped"
                progress_data['message'] = "Training stopped by user request"
                with open(progress_file, 'w') as f:
                    json.dump(progress_data, f)
        return {"success": True, "data": progress_data}
    except Exception as e:
        logger.error(f"Error reading training progress: {str(e)}")
        return {
            "success": False,
            "message": f"Error reading training progress: {str(e)}"
        }

@router.get("/training-charts")
async def get_training_charts():
    """Get all available training charts (file system only)"""
    try:
        charts_dir = Path("app/models/trained_models/training_charts")
        os.makedirs(charts_dir, exist_ok=True)
        if not charts_dir.exists():
            logger.warning(f"Training charts directory not found at {charts_dir}")
            return {"charts": []}
        chart_files = []
        for file in charts_dir.glob("*.png"):
            chart_files.append(str(file))
        logger.info(f"Found {len(chart_files)} training chart files")
        return {"charts": chart_files}
    except Exception as e:
        logger.error(f"Error fetching training charts: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error fetching training charts: {str(e)}")
