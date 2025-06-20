from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import desc, text
from typing import Optional, Dict, Any, List
from pathlib import Path
import json
import logging
import traceback
import tempfile
import os
import time
from ..database import get_db
from ..models.trained_model import TrainedModel

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
async def get_datasets(db: Session = Depends(get_db)):
    """Get all available datasets for model training"""
    try:
        # Get datasets from the fish_images directory
        datasets_dir = Path("app/datasets/fish_images")
        if not datasets_dir.exists():
            return []
            
        # Check for train/val/test subdirectories
        train_dir = datasets_dir / "train"
        if not train_dir.exists() or not train_dir.is_dir():
            return []
            
        # Get all class directories in the train folder
        class_dirs = [d for d in train_dir.iterdir() if d.is_dir()]
        
        # Count images in each class directory
        datasets = []
        for class_dir in class_dirs:
            train_count = len(list(class_dir.glob("*.jpg")))
            
            # Check if this class also exists in validation and test sets
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
    db: Session = Depends(get_db),
    # This will capture all selectedSpecies[] form fields
    selected_species: Optional[List[str]] = Form(None)
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
            
            # Create a temporary directory with symlinks to all species images
            import tempfile
            import os
            import shutil
            
            # Create a temporary directory for the dataset
            with tempfile.TemporaryDirectory() as temp_data_dir:
                # Create train/val/test directories
                for split in ["train", "val", "test"]:
                    os.makedirs(os.path.join(temp_data_dir, split), exist_ok=True)
                
                # Get all species from the fish_species table
                species_query = text("""
                    SELECT id, common_name 
                    FROM fish_species
                    ORDER BY common_name
                """)
                species_result = db.execute(species_query).fetchall()
                
                # Track all species IDs for later use
                all_species_ids = []
                
                # For each species in the database, create a directory and symlink the images
                for row in species_result:
                    # Get database ID and common name
                    db_id = row[0]
                    species_name = row[1]
                    
                    # Convert species_name to directory name (replace spaces with underscores)
                    dir_name = species_name.replace(" ", "_").lower()
                    all_species_ids.append(dir_name)
                    
                    # Store fish data for later use
                    fish_data = {'id': db_id, 'common_name': species_name}
                    
                    # First check what columns are available in fish_images
                    columns_query = text("""
                        SELECT column_name 
                        FROM information_schema.columns 
                        WHERE table_name = 'fish_images'
                    """)
                    
                    # Try a more direct query approach
                    query = text("""
                        SELECT id, image_name, image_data, dataset_type 
                        FROM fish_images 
                        WHERE fish_species = :species_name
                    """)
                    
                    # Log the query and parameters
                    logger.info(f"Executing query: {query}")
                    logger.info(f"Query parameters: {{'species_name': {species_name}}}")
                    
                    # Use the species name instead of ID for matching
                    result = db.execute(query, {"species_name": species_name}).fetchall()
                    
                    # Debug: Log the number of images found
                    logger.info(f"Found {len(result)} images for species {species_name}")
                    
                    # Map dataset_type to directory name (handle both uppercase and lowercase)
                    dataset_type_map = {
                        "training": "train",
                        "train": "train",
                        "TRAIN": "train",
                        "VALIDATION": "val",
                        "val": "val",
                        "VAL": "val",
                        "TEST": "test",
                        "test": "test"
                    }
                    
                    # Create species directories in each split
                    for split in dataset_type_map.values():
                        os.makedirs(os.path.join(temp_data_dir, split, dir_name), exist_ok=True)
                    
                    # Get all images for this species
                    images_for_species = []
                    for row in result:
                        image_id, image_name, image_data, dataset_type = row
                        if dataset_type and dataset_type.lower() in dataset_type_map:
                            split = dataset_type_map[dataset_type.lower()]
                            images_for_species.append((split, image_id, image_name, image_data))
                    
                    # Only create directories and save images if we have images for this species
                    if images_for_species:
                        logger.info(f"Found {len(images_for_species)} images for species {species_name}")
                        
                        # Create directories for this species
                        for split in dataset_type_map.values():
                            os.makedirs(os.path.join(temp_data_dir, split, dir_name), exist_ok=True)
                        
                        # Save all images
                        for split, image_id, image_name, image_data in images_for_species:
                            target_dir = os.path.join(temp_data_dir, split, dir_name)
                            
                            # Make sure we use a valid image extension that PyTorch can recognize
                            # Extract original extension if available, otherwise default to jpg
                            ext = '.jpg'
                            if image_name and '.' in image_name:
                                original_ext = os.path.splitext(image_name)[1].lower()
                                if original_ext in ['.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff']:
                                    ext = original_ext
                            
                            # Create a file with the image data
                            target_path = os.path.join(target_dir, f"{image_id}{ext}")
                            
                            # Write the binary image data to a file
                            with open(target_path, 'wb') as f:
                                f.write(image_data)
                    else:
                        logger.warning(f"No images found for species {species_name} (ID: {db_id})")
                    
                
                # Collect species with images for training
                species_with_images = {}
                
                # First, identify which species have images
                for species_name, species_id in [(row[1], row[0]) for row in species_result]:
                    # Convert to directory name format
                    dir_name = species_name.replace(" ", "_").lower()
                    
                    # Get images for this species - try both with spaces and with underscores
                    query = text("""
                        SELECT id, image_name, image_data, dataset_type 
                        FROM fish_images 
                        WHERE fish_species = :species_name OR fish_species = :species_name_underscore
                    """)
                    
                    # Try both formats: with spaces and with underscores
                    species_name_underscore = species_name.replace(" ", "_")
                    
                    result = db.execute(query, {
                        "species_name": species_name,
                        "species_name_underscore": species_name_underscore
                    }).fetchall()
                    
                    logger.info(f"Found {len(result)} images for species {species_name} (or {species_name_underscore})")
                    
                    # If no results, also try the reverse (if name has underscores, try with spaces)
                    if not result and "_" in species_name:
                        species_name_with_spaces = species_name.replace("_", " ")
                        query = text("""
                            SELECT id, image_name, image_data, dataset_type 
                            FROM fish_images 
                            WHERE fish_species = :species_name_with_spaces
                        """)
                        result = db.execute(query, {"species_name_with_spaces": species_name_with_spaces}).fetchall()
                        logger.info(f"Found {len(result)} images for species {species_name_with_spaces} (alternative format)")
                    
                    
                    # Only include species with images
                    if result:
                        species_with_images[dir_name] = {
                            'name': species_name,
                            'id': species_id,
                            'images': result
                        }
                    else:
                        logger.warning(f"No images found for species {species_name} (ID: {species_id})")
                
                # If no species have images, return an error
                if not species_with_images:
                    raise HTTPException(
                        status_code=400,
                        detail="No valid training images found. Please upload training images for at least one species before training the model."
                    )
                
                # Map dataset_type to directory name (handle both uppercase and lowercase)
                dataset_type_map = {
                    "training": "train",
                    "train": "train",
                    "TRAIN": "train",
                    "VALIDATION": "val",
                    "val": "val",
                    "VAL": "val",
                    "TEST": "test",
                    "test": "test"
                }
                
                # Create directories and save images only for species that have images
                total_images = 0
                for dir_name, species_data in species_with_images.items():
                    # Create directories for this species
                    for split in dataset_type_map.values():
                        os.makedirs(os.path.join(temp_data_dir, split, dir_name), exist_ok=True)
                    
                    # Process and save all images for this species
                    train_images = 0
                    for image_id, image_name, image_data, dataset_type in species_data['images']:
                        if dataset_type and dataset_type in dataset_type_map:
                            split = dataset_type_map[dataset_type]
                            
                            # Make sure we use a valid image extension
                            ext = '.jpg'
                            if image_name and '.' in image_name:
                                original_ext = os.path.splitext(image_name)[1].lower()
                                if original_ext in ['.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff']:
                                    ext = original_ext
                            
                            # Save the image
                            target_dir = os.path.join(temp_data_dir, split, dir_name)
                            target_path = os.path.join(target_dir, f"{image_id}{ext}")
                            
                            with open(target_path, 'wb') as f:
                                f.write(image_data)
                            
                            if split == 'train':
                                train_images += 1
                                total_images += 1
                    
                    logger.info(f"Saved {train_images} training images for {species_data['name']}")
                
                # Check if we have enough species and images for training
                if len(species_with_images) < 2:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Found only {len(species_with_images)} species with images. At least 2 species are required for classification."
                    )
                
                logger.info(f"Prepared {total_images} training images across {len(species_with_images)} species for model training.")
                
                # Make sure the stop flag is reset before training
                global STOP_TRAINING
                STOP_TRAINING = False
                
                # Train the CNN model using the temporary directory with stop flag callback
                accuracy, training_logs = train_cnn_model(
                    species_name=species_name,  # Pass the species name for better logging
                    data_dir=temp_data_dir,
                    model_out_path=model_out_path,
                    image_size=image_size,
                    batch_size=batch_size,
                    learning_rate=learning_rate,
                    epochs=epochs,
                    use_data_augmentation=use_data_augmentation,
                    stop_flag_callback=check_stop_flag  # Use the new callback function
                )
                
                # Reset stop flag after training
                STOP_TRAINING = False
            
            # Get number of classes from all species
            num_classes = len(all_species_ids)
            
            # Create model record in database
            db_model = TrainedModel(
                model_type=model_type,
                file_path=model_out_path,
                version=Path(model_out_path).stem,
                accuracy=accuracy,
                parameters=json.dumps({
                    "learning_rate": learning_rate,
                    "epochs": epochs,
                    "batch_size": batch_size,
                    "image_size": image_size,
                    "use_data_augmentation": use_data_augmentation
                }),
                num_classes=num_classes,
                training_dataset="All database species",
                is_active=True
            )
            
            # Set all other CNN models as inactive
            db.query(TrainedModel).filter(
                TrainedModel.model_type == model_type,
                TrainedModel.id != db_model.id
            ).update({"is_active": False})
            
            db.add(db_model)
            db.commit()
            
            return {
                "message": f"{model_type.upper()} model trained successfully",
                "model_id": db_model.id,
                "file_path": model_out_path,
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
        db.rollback()
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
    db: Session = Depends(get_db)
):
    """Save a trained model to the database"""
    try:
        # Check if the model file exists
        model_path = f"app/models/trained_models/{model_id}"
        if not os.path.exists(model_path):
            logger.error(f"Model file not found at {model_path}")
            raise HTTPException(
                status_code=404, 
                detail="Model file not found. Training may have been stopped before completion."
            )
        
        # Create model record
        db_model = TrainedModel(
            model_type=model_type,
            file_path=model_path,
            version=version,
            accuracy=accuracy,
            parameters=json.dumps(parameters),
            is_active=is_active
        )
        
        # If this model is active, deactivate all other models of the same type
        if is_active:
            db.query(TrainedModel).filter(
                TrainedModel.model_type == model_type,
                TrainedModel.id != db_model.id
            ).update({"is_active": False})
        
        db.add(db_model)
        db.commit()
        
        return {"message": "Model saved successfully", "model_id": db_model.id}
    except HTTPException as e:
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error saving model: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error saving model: {str(e)}")

@router.get("/")
async def get_models(db: Session = Depends(get_db)):
    """Get all trained models"""
    models = db.query(TrainedModel).order_by(desc(TrainedModel.created_at)).all()
    return models

@router.get("/{model_type}/active")
async def get_active_model(model_type: str, db: Session = Depends(get_db)):
    """Get the active model for a specific type"""
    model = db.query(TrainedModel).filter(
        TrainedModel.model_type == model_type,
        TrainedModel.is_active == True
    ).first()
    
    if not model:
        raise HTTPException(status_code=404, detail=f"No active {model_type} model found")
    
    return model

@router.put("/{model_id}/activate")
async def activate_model(model_id: int, db: Session = Depends(get_db)):
    """Activate a specific model and deactivate all others of the same type"""
    model = db.query(TrainedModel).filter(TrainedModel.id == model_id).first()
    
    if not model:
        raise HTTPException(status_code=404, detail="Model not found")
    
    # Deactivate all other models of the same type
    db.query(TrainedModel).filter(
        TrainedModel.model_type == model.model_type,
        TrainedModel.id != model_id
    ).update({"is_active": False})
    
    # Activate this model
    model.is_active = True
    db.commit()
    
    return {"message": f"Model {model_id} activated successfully"}

@router.delete("/{model_id}")
async def delete_model(model_id: int, db: Session = Depends(get_db)):
    """Delete a model from the database and file system"""
    model = db.query(TrainedModel).filter(TrainedModel.id == model_id).first()
    
    if not model:
        raise HTTPException(status_code=404, detail="Model not found")
    
    # Delete the model file if it exists
    if os.path.exists(model.file_path):
        os.remove(model.file_path)
    
    # Delete from database
    db.delete(model)
    db.commit()
    
    return {"message": f"Model {model_id} deleted successfully"}

@router.post("/stop-training")
async def stop_training(model_type: Optional[str] = None):
    """Stop the current model training process"""
    try:
        # Create the stop signal file
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        
        # Write to the stop signal file
        with open(stop_signal_path, "w") as f:
            f.write(f"STOP=TRUE\nTimestamp={time.time()}\nRequested by user")
        
        logger.info(f"Created stop signal file at {stop_signal_path}")
        
        # Update the progress file to indicate training is stopping
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
                
            # Update progress file if it exists
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
    """Get the current training progress for a specific model type"""
    try:
        # Check which progress file to use
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
            
        # Create progress file if it doesn't exist
        if not os.path.exists(progress_file):
            os.makedirs(os.path.dirname(progress_file), exist_ok=True)
            with open(progress_file, "w") as f:
                import json
                json.dump({
                    "status": "idle",
                    "progress": 0,
                    "timestamp": time.time()
                }, f)
        
        # Read progress data
        with open(progress_file, "r") as f:
            import json
            progress_data = json.load(f)
        
        # Check for training inactivity timeout
        current_time = time.time()
        last_update_time = progress_data.get('timestamp', 0)
        
        # Only apply timeout if training is in progress (not for idle or stopped states)
        if progress_data.get('status') == 'training' and (current_time - last_update_time) > 10:
            logger.info(f"Training appears inactive (no updates for {current_time - last_update_time:.1f} seconds). Setting status to stopped.")
            progress_data['status'] = 'stopped'
            progress_data['message'] = 'Training stopped due to inactivity'
            
            # Write updated status to file
            with open(progress_file, 'w') as f:
                json.dump(progress_data, f)
                
            # Create stop signal file if it doesn't exist
            stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
            if not os.path.exists(stop_signal_path):
                with open(stop_signal_path, 'w') as f:
                    f.write(f"FORCE_STOP=TRUE\nStop requested due to inactivity at {time.time()}")
        
        # Check for stop_training_signal.txt using absolute path
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        if os.path.exists(stop_signal_path):
            # Only log this message once per minute to reduce log spam
            current_time = time.time()
            last_log_time = getattr(get_training_progress, 'last_log_time', 0)
            if current_time - last_log_time > 60:
                logger.info(f"Found stop signal file at {stop_signal_path}, returning stopped status")
                get_training_progress.last_log_time = current_time
                
            # Update progress data only if not already stopped
            if progress_data.get('status') != 'stopped':
                progress_data['status'] = "stopped"
                progress_data['message'] = "Training stopped by user request"
                
                # Write updated status to file
                with open(progress_file, 'w') as f:
                    json.dump(progress_data, f)
            
        return {"success": True, "data": progress_data}
    except Exception as e:
        logger.error(f"Error reading training progress: {str(e)}")
        return {
            "success": False,
            "message": f"Error reading training progress: {str(e)}"
        }

def get_recent_logs(num_lines=50):
    """Get the most recent lines from the log file"""
    import os
    
    # Define the log file path (adjust this to your actual log file location)
    log_file = os.path.join(os.getcwd(), 'training.log')
    
    if not os.path.exists(log_file):
        return []
    
    try:
        # Read the last num_lines from the log file
        with open(log_file, 'r') as f:
            lines = f.readlines()
        
        # Return the last num_lines
        return lines[-num_lines:] if len(lines) > num_lines else lines
    except Exception as e:
        logger.error(f"Error reading log file: {e}")
        return []

@router.get("/training-charts")
async def get_training_charts():
    """Get all available training charts"""
    try:
        # Define charts directory
        charts_dir = Path("app/models/trained_models/training_charts")
        
        # Create directory if it doesn't exist
        os.makedirs(charts_dir, exist_ok=True)
        
        if not charts_dir.exists():
            logger.warning(f"Training charts directory not found at {charts_dir}")
            return {"charts": []}
            
        # List all chart files
        chart_files = []
        for file in charts_dir.glob("*.png"):
            # Store the absolute path for easier access
            chart_files.append(str(file))
        
        logger.info(f"Found {len(chart_files)} training chart files")
        return {"charts": chart_files}
    except Exception as e:
        logger.error(f"Error fetching training charts: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error fetching training charts: {str(e)}")
