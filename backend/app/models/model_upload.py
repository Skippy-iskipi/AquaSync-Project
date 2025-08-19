# app/models/model_upload.py

import os
import tempfile
from datetime import datetime
import logging
import traceback
from typing import Tuple, Dict, Any, Optional, List
from pathlib import Path

# Import Supabase client
try:
    from ..supabase_config import get_supabase_client
except ImportError:
    # Fallback for different import paths
    from supabase_config import get_supabase_client

logger = logging.getLogger(__name__)

class ModelUploadManager:
    """
    Manages model uploads to Supabase storage and metadata tracking.
    """
    
    def __init__(self, bucket_name: str = "models"):
        self.bucket_name = bucket_name
        self.supabase = None
        
    def _get_supabase_client(self):
        """Get or initialize Supabase client."""
        if self.supabase is None:
            self.supabase = get_supabase_client()
        return self.supabase
        
    def upload_model_to_storage(self, 
                              model_path: str, 
                              model_name: Optional[str] = None,
                              folder: str = "trained_models") -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Upload a trained model to Supabase storage bucket.
        
        Args:
            model_path: Local path to the model file
            model_name: Name for the model in storage. If None, generates timestamp-based name
            folder: Folder within the bucket to store the model
        
        Returns:
            tuple: (success: bool, storage_path: str or None, error_message: str or None)
        """
        try:
            supabase = self._get_supabase_client()
            
            # Generate model name if not provided
            if model_name is None:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                model_name = f"efficientnet_b3_fish_classifier_{timestamp}.pth"
            
            # Ensure the model file exists
            if not os.path.exists(model_path):
                error_msg = f"Model file not found: {model_path}"
                logger.error(error_msg)
                return False, None, error_msg
            
            # Storage path in bucket
            storage_path = f"{folder}/{model_name}" if folder else model_name
            
            logger.info(f"Uploading model to Supabase storage: {storage_path}")
            
            # Read the model file
            with open(model_path, 'rb') as f:
                model_data = f.read()
            
            # Check file size
            file_size_mb = len(model_data) / (1024 * 1024)
            logger.info(f"Model file size: {file_size_mb:.2f} MB")
            
            # Upload to Supabase storage
            try:
                response = supabase.storage.from_(self.bucket_name).upload(
                    file=model_data,
                    path=storage_path,
                    file_options={"content-type": "application/octet-stream"}
                )
                
                # Check if there's an error in the response
                if hasattr(response, 'error') and response.error:
                    error_msg = f"Failed to upload model to Supabase: {response.error}"
                    logger.error(error_msg)
                    return False, None, error_msg
                
            except Exception as upload_error:
                # Try to handle file already exists error
                if "already exists" in str(upload_error).lower():
                    logger.warning(f"File already exists, trying to update: {storage_path}")
                    try:
                        # Update existing file
                        response = supabase.storage.from_(self.bucket_name).update(
                            file=model_data,
                            path=storage_path,
                            file_options={"content-type": "application/octet-stream"}
                        )
                        
                        if hasattr(response, 'error') and response.error:
                            error_msg = f"Failed to update existing model: {response.error}"
                            logger.error(error_msg)
                            return False, None, error_msg
                        
                    except Exception as update_error:
                        error_msg = f"Failed to update existing model: {str(update_error)}"
                        logger.error(error_msg)
                        return False, None, error_msg
                else:
                    error_msg = f"Upload failed: {str(upload_error)}"
                    logger.error(error_msg)
                    return False, None, error_msg
            
            # Get the public URL for the uploaded model
            try:
                public_url = supabase.storage.from_(self.bucket_name).get_public_url(storage_path)
                logger.info(f"Successfully uploaded model to Supabase storage")
                logger.info(f"Storage path: {storage_path}")
                logger.info(f"Public URL: {public_url}")
            except Exception as url_error:
                logger.warning(f"Could not get public URL: {str(url_error)}")
            
            return True, storage_path, None
            
        except Exception as e:
            error_msg = f"Error uploading model to Supabase: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            return False, None, error_msg

    def save_model_metadata(self, 
                           model_name: str,
                           storage_path: str,
                           accuracy: float,
                           num_classes: int,
                           class_names: List[str],
                           training_params: Optional[Dict[str, Any]] = None,
                           model_type: str = "efficientnet_b3") -> Tuple[bool, Optional[str]]:
        """
        Save model metadata to the trained_models table.
        
        Args:
            model_name: Name of the model
            storage_path: Path in Supabase storage
            accuracy: Best validation accuracy achieved
            num_classes: Number of classes the model was trained on
            class_names: List of class names
            training_params: Training parameters used
            model_type: Type of model architecture
        
        Returns:
            tuple: (success: bool, error_message: str or None)
        """
        try:
            supabase = self._get_supabase_client()
            
            # Prepare metadata
            metadata = {
                "model_name": model_name,
                "storage_path": storage_path,
                "accuracy": float(accuracy),
                "num_classes": int(num_classes),
                "class_names": class_names,
                "training_params": training_params or {},
                "model_type": model_type,
                "status": "active"
            }
            
            logger.info(f"Saving model metadata: {model_name}, accuracy: {accuracy:.4f}")
            
            # Insert into trained_models table
            response = supabase.table('trained_models').insert(metadata).execute()
            
            if hasattr(response, 'error') and response.error:
                error_msg = f"Failed to save model metadata: {response.error}"
                logger.error(error_msg)
                return False, error_msg
            
            logger.info(f"Successfully saved model metadata to database")
            return True, None
            
        except Exception as e:
            error_msg = f"Error saving model metadata: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            return False, error_msg

    def create_training_session(self, 
                              session_name: Optional[str] = None,
                              dataset_path: str = "",
                              num_samples: int = 0,
                              hyperparameters: Optional[Dict[str, Any]] = None) -> Optional[str]:
        """
        Create a new training session record.
        
        Args:
            session_name: Name for the training session
            dataset_path: Path to the training dataset
            num_samples: Number of training samples
            hyperparameters: Training hyperparameters
        
        Returns:
            session_id: UUID of the created session or None if failed
        """
        try:
            supabase = self._get_supabase_client()
            
            if session_name is None:
                session_name = f"Training_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            session_data = {
                "session_name": session_name,
                "dataset_path": dataset_path,
                "num_samples": num_samples,
                "hyperparameters": hyperparameters or {},
                "status": "running"
            }
            
            response = supabase.table('training_sessions').insert(session_data).execute()
            
            if hasattr(response, 'error') and response.error:
                logger.error(f"Failed to create training session: {response.error}")
                return None
            
            session_id = response.data[0]['id'] if response.data else None
            logger.info(f"Created training session: {session_id}")
            return session_id
            
        except Exception as e:
            logger.error(f"Error creating training session: {str(e)}")
            return None

    def update_training_session(self, 
                              session_id: str,
                              status: str,
                              model_id: Optional[str] = None,
                              final_accuracy: Optional[float] = None,
                              best_epoch: Optional[int] = None,
                              total_epochs: Optional[int] = None,
                              error_message: Optional[str] = None) -> bool:
        """
        Update a training session with completion status.
        
        Args:
            session_id: UUID of the training session
            status: New status ('completed', 'failed', 'stopped')
            model_id: UUID of the resulting model (if successful)
            final_accuracy: Final accuracy achieved
            best_epoch: Best epoch number
            total_epochs: Total epochs run
            error_message: Error message if failed
        
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            supabase = self._get_supabase_client()
            
            update_data = {
                "status": status,
                "end_time": datetime.now().isoformat()
            }
            
            if model_id:
                update_data["model_id"] = model_id
            if final_accuracy is not None:
                update_data["final_accuracy"] = float(final_accuracy)
            if best_epoch is not None:
                update_data["best_epoch"] = int(best_epoch)
            if total_epochs is not None:
                update_data["total_epochs"] = int(total_epochs)
            if error_message:
                update_data["error_message"] = error_message
            
            response = supabase.table('training_sessions').update(update_data).eq('id', session_id).execute()
            
            if hasattr(response, 'error') and response.error:
                logger.error(f"Failed to update training session: {response.error}")
                return False
            
            logger.info(f"Updated training session {session_id} with status: {status}")
            return True
            
        except Exception as e:
            logger.error(f"Error updating training session: {str(e)}")
            return False

    def update_production_model(self, 
                              storage_path: str, 
                              model_name: str,
                              notes: Optional[str] = None) -> Tuple[bool, Optional[str]]:
        """
        Update the production model reference to point to the new best model.
        
        Args:
            storage_path: Storage path of the new model
            model_name: Name of the model
            notes: Optional notes about the update
        
        Returns:
            tuple: (success: bool, error_message: str or None)
        """
        try:
            supabase = self._get_supabase_client()
            
            # Get current production model for backup
            current_config = supabase.table('model_config').select('*').limit(1).execute()
            
            config_data = {
                "active_model_path": storage_path,
                "active_model_name": model_name,
                "updated_at": datetime.now().isoformat()
            }
            
            if notes:
                config_data["notes"] = notes
            
            # If there's a current config, save it as previous
            if current_config.data:
                current = current_config.data[0]
                config_data["previous_model_path"] = current.get("active_model_path")
                config_data["previous_model_name"] = current.get("active_model_name")
                
                # Update existing config
                response = supabase.table('model_config').update(config_data).eq('id', current['id']).execute()
            else:
                # Insert new config
                response = supabase.table('model_config').insert(config_data).execute()
            
            if hasattr(response, 'error') and response.error:
                error_msg = f"Failed to update production model config: {response.error}"
                logger.error(error_msg)
                return False, error_msg
            
            logger.info(f"Successfully updated production model configuration")
            logger.info(f"New active model: {model_name} at {storage_path}")
            return True, None
            
        except Exception as e:
            error_msg = f"Error updating production model config: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            return False, error_msg

    def get_best_models(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get the best performing models.
        
        Args:
            limit: Maximum number of models to return
        
        Returns:
            List of model dictionaries sorted by accuracy
        """
        try:
            supabase = self._get_supabase_client()
            
            response = supabase.table('trained_models')\
                .select('*')\
                .eq('status', 'active')\
                .order('accuracy', desc=True)\
                .order('created_at', desc=True)\
                .limit(limit)\
                .execute()
            
            if hasattr(response, 'error') and response.error:
                logger.error(f"Failed to get best models: {response.error}")
                return []
            
            return response.data or []
            
        except Exception as e:
            logger.error(f"Error getting best models: {str(e)}")
            return []

    def archive_old_models(self, keep_count: int = 10) -> int:
        """
        Archive old models, keeping only the top N by accuracy.
        
        Args:
            keep_count: Number of top models to keep active
        
        Returns:
            Number of models archived
        """
        try:
            supabase = self._get_supabase_client()
            
            # Get all active models ordered by accuracy
            response = supabase.table('trained_models')\
                .select('id, accuracy, created_at')\
                .eq('status', 'active')\
                .order('accuracy', desc=True)\
                .order('created_at', desc=True)\
                .execute()
            
            if not response.data or len(response.data) <= keep_count:
                logger.info(f"No models to archive (have {len(response.data) if response.data else 0}, keeping {keep_count})")
                return 0
            
            # Get IDs of models to archive
            models_to_archive = response.data[keep_count:]
            archive_ids = [model['id'] for model in models_to_archive]
            
            # Archive the models
            for model_id in archive_ids:
                archive_response = supabase.table('trained_models')\
                    .update({'status': 'archived'})\
                    .eq('id', model_id)\
                    .execute()
                
                if hasattr(archive_response, 'error') and archive_response.error:
                    logger.error(f"Failed to archive model {model_id}: {archive_response.error}")
            
            logger.info(f"Archived {len(archive_ids)} old models")
            return len(archive_ids)
            
        except Exception as e:
            logger.error(f"Error archiving old models: {str(e)}")
            return 0

    def complete_model_upload_pipeline(self,
                                     model_path: str,
                                     accuracy: float,
                                     num_classes: int,
                                     class_names: List[str],
                                     training_params: Optional[Dict[str, Any]] = None,
                                     accuracy_threshold: float = 0.80,
                                     update_production_threshold: float = 0.90,
                                     session_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Complete pipeline for uploading a model and managing metadata.
        
        Args:
            model_path: Local path to the model file
            accuracy: Model accuracy
            num_classes: Number of classes
            class_names: List of class names
            training_params: Training parameters
            accuracy_threshold: Minimum accuracy to upload
            update_production_threshold: Minimum accuracy to update production
            session_id: Training session ID to update
        
        Returns:
            Dictionary with pipeline results
        """
        result = {
            'uploaded': False,
            'storage_path': None,
            'metadata_saved': False,
            'production_updated': False,
            'session_updated': False,
            'error': None,
            'archived_count': 0
        }
        
        try:
            # Check accuracy threshold
            if accuracy < accuracy_threshold:
                result['error'] = f"Accuracy {accuracy:.4f} below threshold {accuracy_threshold}"
                logger.info(result['error'])
                
                # Still update session if provided
                if session_id:
                    self.update_training_session(
                        session_id=session_id,
                        status="completed",
                        final_accuracy=accuracy,
                        error_message=result['error']
                    )
                    result['session_updated'] = True
                
                return result
            
            # Generate model name
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            model_name = f"efficientnet_b3_fish_classifier_acc{accuracy:.3f}_{timestamp}.pth"
            
            # Upload model
            upload_success, storage_path, upload_error = self.upload_model_to_storage(
                model_path=model_path,
                model_name=model_name
            )
            
            if not upload_success:
                result['error'] = upload_error
                if session_id:
                    self.update_training_session(
                        session_id=session_id,
                        status="failed",
                        error_message=upload_error
                    )
                    result['session_updated'] = True
                return result
            
            result['uploaded'] = True
            result['storage_path'] = storage_path
            
            # Save metadata
            metadata_success, metadata_error = self.save_model_metadata(
                model_name=model_name,
                storage_path=storage_path,
                accuracy=accuracy,
                num_classes=num_classes,
                class_names=class_names,
                training_params=training_params
            )
            
            if metadata_success:
                result['metadata_saved'] = True
            else:
                logger.warning(f"Failed to save metadata: {metadata_error}")
                result['error'] = f"Upload succeeded but metadata failed: {metadata_error}"
            
            # Update production if accuracy is high enough
            if accuracy >= update_production_threshold:
                prod_success, prod_error = self.update_production_model(
                    storage_path=storage_path,
                    model_name=model_name,
                    notes=f"Auto-updated due to high accuracy: {accuracy:.4f}"
                )
                
                if prod_success:
                    result['production_updated'] = True
                    logger.info(f"Updated production model due to high accuracy: {accuracy:.4f}")
                else:
                    logger.warning(f"Failed to update production: {prod_error}")
            
            # Archive old models
            try:
                archived_count = self.archive_old_models(keep_count=10)
                result['archived_count'] = archived_count
            except Exception as e:
                logger.warning(f"Failed to archive old models: {str(e)}")
            
            # Update training session
            if session_id:
                session_success = self.update_training_session(
                    session_id=session_id,
                    status="completed",
                    final_accuracy=accuracy
                )
                result['session_updated'] = session_success
            
            logger.info(f"Model upload pipeline completed successfully: {model_name}")
            
        except Exception as e:
            error_msg = f"Error in model upload pipeline: {str(e)}"
            logger.error(error_msg)
            logger.error(traceback.format_exc())
            result['error'] = error_msg
            
            if session_id:
                self.update_training_session(
                    session_id=session_id,
                    status="failed",
                    error_message=error_msg
                )
                result['session_updated'] = True
        
        return result


# Convenience functions for backward compatibility
def upload_model_to_supabase(model_path: str, 
                           model_name: Optional[str] = None, 
                           bucket_name: str = "models") -> Tuple[bool, Optional[str], Optional[str]]:
    """Backward compatible function for model upload."""
    manager = ModelUploadManager(bucket_name=bucket_name)
    return manager.upload_model_to_storage(model_path, model_name)

def save_model_metadata_to_db(model_name: str,
                            storage_path: str,
                            accuracy: float,
                            num_classes: int,
                            class_names: List[str],
                            training_params: Optional[Dict[str, Any]] = None) -> Tuple[bool, Optional[str]]:
    """Backward compatible function for saving metadata."""
    manager = ModelUploadManager()
    return manager.save_model_metadata(
        model_name, storage_path, accuracy, num_classes, class_names, training_params
    )

def update_active_model_in_production(storage_path: str, 
                                    model_name: str) -> Tuple[bool, Optional[str]]:
    """Backward compatible function for updating production model."""
    manager = ModelUploadManager()
    return manager.update_production_model(storage_path, model_name)