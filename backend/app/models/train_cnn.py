import os
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import torchvision.transforms.functional as TF
from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
from torch.utils.data import DataLoader
from torch.optim.lr_scheduler import CosineAnnealingLR
from pathlib import Path
import logging
import argparse
import os
import shutil
import time
from datetime import datetime
import asyncio
import traceback
import json
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import random
import copy
from tqdm import tqdm

# Import the training log manager
from ..main import training_log_manager

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("train_cnn")

# Custom logger that also sends logs to WebSocket
class WebSocketLogger:
    def __init__(self, name):
        self.logger = logging.getLogger(name)
        self.loop = None
        try:
            self.loop = asyncio.get_event_loop()
        except RuntimeError:
            # If no event loop exists in this thread
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
    
    def info(self, message):
        # Log to console first
        self.logger.info(message)
        
        # Then send to WebSocket
        self._send_to_websocket({"type": "log", "message": message})
    
    def error(self, message):
        # Log to console first
        self.logger.error(message)
        
        # Then send to WebSocket with ERROR prefix
        self._send_to_websocket({"type": "log", "message": f"ERROR: {message}", "level": "error"})
    
    def _send_to_websocket(self, message):
        """Send a message to WebSocket clients"""
        try:
            if training_log_manager:
                # Directly broadcast the JSON message using the connection manager's internal method
                # _broadcast sends the message dictionary to all connected clients.
                coro = training_log_manager._broadcast(message)
                try:
                    loop = asyncio.get_event_loop()
                    if loop.is_running():
                        loop.create_task(coro)
                except Exception as e:
                    logger.error(f"Error sending to WebSocket: {str(e)}")
        except Exception as e:
            logger.error(f"Error sending to WebSocket: {str(e)}")

    def warning(self, message):
        self.logger.warning(message)
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                loop.create_task(training_log_manager.broadcast_log(f"WARNING: {message}"))
        except Exception as e:
            self.logger.error(f"Error sending warning log to WebSocket: {e}")

# Create a WebSocket logger instance
ws_logger = WebSocketLogger("train_cnn")

# Custom dataset class that includes class weights
class WeightedImageFolder(datasets.ImageFolder):
    def __init__(self, root, transform=None):
        super(WeightedImageFolder, self).__init__(root=root, transform=transform)
        self.class_weights = None
        self._compute_class_weights()
        
    def _compute_class_weights(self):
        """Compute weights for each class based on frequency"""
        class_counts = [0] * len(self.classes)
        for _, label in self.samples:
            class_counts[label] += 1
            
        # Log class distribution
        for i, (class_name, count) in enumerate(zip(self.classes, class_counts)):
            # Use standard logger to avoid circular dependency
            logger.info(f"Class {i}: {class_name} - {count} images")
            
        # Calculate weights based on inverse frequency
        total_samples = sum(class_counts)
        if min(class_counts) == 0:
            # If any class has 0 samples, don't use class weights
            self.class_weights = None
            logger.warning("Some classes have 0 samples. Not using class weights.")
            return
            
        weights = torch.FloatTensor([
            total_samples / (len(self.classes) * count) if count > 0 else 0
            for count in class_counts
        ])
        self.class_weights = weights
        
        # Log class weights
        class_weight_str = ", ".join(f"{w:.2f}" for w in weights)
        logger.info(f"Class weights: [{class_weight_str}]")

def prepare_dataset(data_dir, min_images_per_class=1):  # Reduced minimum images to ensure classes are included
    """
    Prepare the dataset by filtering out empty directories.
    Only keep directories that contain valid image files.
    Uses space-based names for consistency with database.

    Args:
        data_dir (str): Directory containing train/val subdirectories with class folders
        min_images_per_class (int): Minimum number of images required per class

    Returns:
        str: Path to the prepared dataset directory
        int: Number of valid classes found
    """
    # Validate input directory exists
    if not os.path.exists(data_dir):
        error_msg = f"Dataset directory '{data_dir}' does not exist"
        logger.error(error_msg)
        raise FileNotFoundError(error_msg)

    # Create a temporary directory for the filtered dataset
    temp_dir = os.path.join(os.path.dirname(data_dir), 'temp_dataset_' + os.path.basename(data_dir))
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)

    # Create train and val directories
    train_temp = os.path.join(temp_dir, 'train')
    val_temp = os.path.join(temp_dir, 'val')
    os.makedirs(train_temp, exist_ok=True)
    os.makedirs(val_temp, exist_ok=True)

    valid_extensions = ('.jpg', '.jpeg', '.png', '.ppm', '.bmp', '.pgm', '.tif', '.tiff', '.webp')
    valid_classes = set()

    # Process train directory
    train_dir = os.path.join(data_dir, 'train')
    if not os.path.exists(train_dir):
        error_msg = f"Training directory '{train_dir}' does not exist"
        logger.error(error_msg)
        raise FileNotFoundError(error_msg)

    # Check if train directory has any subdirectories
    train_subdirs = [d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))]
    if not train_subdirs:
        error_msg = f"No class directories found in training directory '{train_dir}'"
        logger.error(error_msg)
        raise FileNotFoundError(error_msg)

    for class_name in train_subdirs:
        # Convert directory name to space-based format
        display_name = class_name.replace('_', ' ').title()
        class_dir = os.path.join(train_dir, class_name)

        # Check if directory contains valid images
        valid_images = [f for f in os.listdir(class_dir)
                       if os.path.isfile(os.path.join(class_dir, f)) and
                       f.lower().endswith(valid_extensions)]

        if len(valid_images) >= min_images_per_class:  # Check minimum images
            # This class has valid images, include it using the display name
            valid_classes.add(display_name)
            new_class_dir = os.path.join(train_temp, display_name)
            os.makedirs(new_class_dir, exist_ok=True)

            # Copy valid images to the new directory
            for img in valid_images:
                shutil.copy2(os.path.join(class_dir, img), os.path.join(new_class_dir, img))
            logger.info(f"Found {len(valid_images)} valid images for class '{display_name}' in training set")
        else:
            logger.warning(f"Skipping class '{display_name}' with only {len(valid_images)} images in training set")

    if not valid_classes:
        error_msg = "No valid classes found with image files. Please check your dataset structure and image formats."
        logger.error(error_msg)
        raise FileNotFoundError(error_msg)

    # Process val directory (only include classes that were valid in train)
    val_dir = os.path.join(data_dir, 'val')
    if not os.path.exists(val_dir):
        # Create validation directory if it doesn't exist
        os.makedirs(val_dir, exist_ok=True)
        
        # Log that we're creating validation data from training data
        logger.info("Validation directory doesn't exist. Creating validation set from training data...")
        
        # For each valid class, move 30% of training images to validation
        for display_name in valid_classes:
            train_class_dir = os.path.join(train_temp, display_name)
            val_class_dir = os.path.join(val_temp, display_name)
            os.makedirs(val_class_dir, exist_ok=True)
            
            # Get all image files in train directory
            images = [f for f in os.listdir(train_class_dir) 
                     if os.path.isfile(os.path.join(train_class_dir, f)) and 
                     f.lower().endswith(valid_extensions)]
            
            # Determine number of images to move (30% of train data)
            num_to_move = max(1, int(0.3 * len(images)))
            images_to_move = random.sample(images, min(num_to_move, len(images)))
            
            # Move images to validation directory
            for img in images_to_move:
                src_path = os.path.join(train_class_dir, img)
                dst_path = os.path.join(val_class_dir, img)
                shutil.copy2(src_path, dst_path)
                os.remove(src_path)  # Remove from training set
                
            logger.info(f"Created validation set for {display_name}: {len(images_to_move)} images")
    else:
        # Original code for existing validation directory
        for class_name in train_subdirs:
            # Convert directory name to space-based format
            display_name = class_name.replace('_', ' ').title()
            if display_name not in valid_classes:
                continue

            class_dir = os.path.join(val_dir, class_name)
            if not os.path.exists(class_dir):
                logger.warning(f"No validation directory found for class '{display_name}'")
                continue

            valid_images = [f for f in os.listdir(class_dir)
                           if os.path.isfile(os.path.join(class_dir, f)) and
                           f.lower().endswith(valid_extensions)]

            if valid_images:
                new_class_dir = os.path.join(val_temp, display_name)
                os.makedirs(new_class_dir, exist_ok=True)

                # Copy valid images to the new directory
                for img in valid_images:
                    shutil.copy2(os.path.join(class_dir, img), os.path.join(new_class_dir, img))
                logger.info(f"Found {len(valid_images)} valid images for class '{display_name}' in validation set")
            else:
                logger.warning(f"No valid images found for class '{display_name}' in validation set")

    num_classes = len(valid_classes)
    logger.info(f"Found {num_classes} valid classes with images")

    if num_classes < 2:
        error_msg = f"Found only {num_classes} classes with valid images. At least 2 classes are required for classification."
        logger.error(error_msg)
        raise ValueError(error_msg)

    # Verify both train and val directories have data
    train_has_data = any(os.path.exists(os.path.join(train_temp, c)) for c in valid_classes)
    val_has_data = any(os.path.exists(os.path.join(val_temp, c)) for c in valid_classes)

    if not train_has_data or not val_has_data:
        error_msg = "Missing data in training or validation sets after preparation"
        logger.error(error_msg)
        raise ValueError(error_msg)

    # Log class counts after filtering
    train_class_counts = {}
    for class_name in os.listdir(train_temp):
        class_path = os.path.join(train_temp, class_name)
        if os.path.isdir(class_path):
            train_class_counts[class_name] = len(os.listdir(class_path))
    logger.info(f"Training set class counts: {train_class_counts}")

    val_class_counts = {}
    for class_name in os.listdir(val_temp):
        class_path = os.path.join(val_temp, class_name)
        if os.path.isdir(class_path):
            val_class_counts[class_name] = len(os.listdir(class_path))
    logger.info(f"Validation set class counts: {val_class_counts}")

    return temp_dir, num_classes

def should_stop():
    """Check if training should be stopped"""
    try:
        # Check for stop signal file using absolute path
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        
        if os.path.exists(stop_signal_path):
            logger.info("Stop signal detected")
            return True
            
        return False
    except Exception as e:
        logger.error(f"Error checking stop signal: {str(e)}")
        return False

def calibrate_confidence(logits, temperature=1.0):
    """
    Apply temperature scaling to calibrate confidence scores.
    
    Args:
        logits: Raw logits from the model
        temperature: Temperature parameter (>1 smooths, <1 sharpens)
    
    Returns:
        Calibrated probabilities
    """
    scaled_logits = logits / temperature
    
    # Handle both batch and single sample inputs
    if len(scaled_logits.shape) == 1:
        # Single sample (1D tensor)
        return torch.nn.functional.softmax(scaled_logits, dim=0)
    else:
        # Batch of samples (2D tensor)
        return torch.nn.functional.softmax(scaled_logits, dim=1)

def verify_model_forward_pass(model, input_size=224, device=None):
    """
    Verify that the model can perform a forward pass with a dummy input.
    This helps catch shape mismatch errors early.
    
    Args:
        model: The PyTorch model to verify
        input_size: The input image size the model expects
        device: The device to run the test on (CPU/CUDA)
        
    Returns:
        True if forward pass succeeds, False otherwise
    """
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Print model structure
    logger.info(f"Model verification - model type: {type(model).__name__}")
    
    # Try to get model architecture details
    try:
        if hasattr(model, 'classifier'):
            logger.info(f"Model has classifier: {model.classifier}")
            
        if hasattr(model, 'fc'):
            logger.info(f"Model has fc layer: {model.fc}")
    except Exception as e:
        logger.warning(f"Could not print model details: {str(e)}")
    
    # Create a dummy input tensor
    dummy_input = torch.randn(1, 3, input_size, input_size).to(device)
    
    # Test the model
    model.eval()  # Set to eval mode
    
    try:
        logger.info(f"Verifying model forward pass with dummy input of shape {dummy_input.shape}")
        
        # For debugging, let's trace through the forward pass step by step
        with torch.no_grad():
            # Try features first if the model has that attribute
            if hasattr(model, 'features'):
                logger.info("Testing feature extraction...")
                features = model.features(dummy_input)
                logger.info(f"Features output shape: {features.shape}")
            
            # Now try the complete forward pass
            logger.info("Testing the complete forward pass...")
            outputs = model(dummy_input)
            logger.info(f"Full forward pass successful, output shape: {outputs.shape}")
            logger.info("Model forward pass verification: SUCCESS")
            return True
    except Exception as e:
        logger.error(f"Model forward pass verification failed: {str(e)}")
        logger.error(traceback.format_exc())
        return False

def train_cnn_model(species_name, 
                  data_dir, 
                  model_out_path, 
                  epochs=100, 
                  batch_size=8, 
                  learning_rate=0.0001, 
                  image_size=224, 
                  use_data_augmentation=True,
                  stop_flag_callback=None,
                  calibration_temperature=1.5):
    """Train a CNN model for fish species classification"""
    global should_stop
    should_stop = stop_flag_callback if stop_flag_callback else lambda: False
    
    try:
        # Create data loaders
        train_loader, val_loader, train_dataset, num_classes = create_dataloaders(
            data_dir=data_dir,
            image_size=image_size,
            batch_size=batch_size,
            use_data_augmentation=use_data_augmentation
        )
        
        # Check if we have enough data
        if len(train_dataset) < 10:
            logger.error(f"Not enough training data: {len(train_dataset)} samples. Need at least 10.")
            raise ValueError(f"Not enough training data: {len(train_dataset)} samples. Need at least 10.")
        
        # Create model
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        logger.info(f"Using device: {device}")
        
        model = create_model(num_classes=num_classes)
        model = model.to(device)
        
        # Verify model forward pass works with a dummy input
        if not verify_model_forward_pass(model, input_size=image_size, device=device):
            logger.error("Model verification failed! The architecture may have shape mismatch issues.")
            # Try to fix the model with a simpler approach
            logger.info("Attempting to recreate the model with a simpler architecture...")
            model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
            
            # Replace only the final classification layer
            num_ftrs = model.classifier[1].in_features
            model.classifier[1] = nn.Linear(num_ftrs, num_classes)
            
            model = model.to(device)
            
            # Verify the fixed model
            if not verify_model_forward_pass(model, input_size=image_size, device=device):
                # Last-resort fallback - create the simplest possible model from scratch
                logger.warning("All attempts failed. Creating a bare-bones CNN model as final fallback...")
                
                # Create a simple CNN model from scratch
                from torchvision.models import resnet18
                model = resnet18(weights=None)  # No pretrained weights
                model.fc = nn.Linear(model.fc.in_features, num_classes)
                model = model.to(device)
                
                # Verify if even this works
                if not verify_model_forward_pass(model, input_size=image_size, device=device):
                    raise RuntimeError("All model architecture attempts failed. Please check PyTorch and torchvision versions for compatibility.")
        
        # Generate class weights if needed
        if train_dataset.class_weights is not None:
            # Move class weights to the same device as the model
            class_weights = train_dataset.class_weights.to(device)
            criterion = nn.CrossEntropyLoss(weight=class_weights)
            logger.info(f"Using weighted CrossEntropyLoss with class weights")
        else:
            criterion = nn.CrossEntropyLoss()
            logger.info(f"Using standard CrossEntropyLoss (no class weights)")
        
        # Create optimizer with weight decay
        optimizer = optim.AdamW(model.parameters(), lr=learning_rate, weight_decay=0.01)
        
        # Create learning rate scheduler
        scheduler = optim.lr_scheduler.ReduceLROnPlateau(
            optimizer, mode='max', factor=0.5, patience=5, verbose=True
        )
        
        # Print model summary before training
        logger.info(f"Training model with the following parameters:")
        logger.info(f"- Epochs: {epochs}")
        logger.info(f"- Batch size: {batch_size}")
        logger.info(f"- Learning rate: {learning_rate}")
        logger.info(f"- Data augmentation: {use_data_augmentation}")
        logger.info(f"- Number of classes: {num_classes}")
        logger.info(f"- Training samples: {len(train_dataset)}")
        logger.info(f"- Calibration temperature: {calibration_temperature}")
        
        # Train the model
        best_model_state_dict, best_accuracy = train_model(
            model=model,
            train_loader=train_loader,
            val_loader=val_loader,
            criterion=criterion,
            optimizer=optimizer,
            scheduler=scheduler,
            num_epochs=epochs,
            device=device,
            calibration_temperature=calibration_temperature,
            patience=15
        )
        
        # Save the best model with checkpoint information
        checkpoint = {
            'model_state_dict': best_model_state_dict,
            'optimizer_state_dict': optimizer.state_dict(),
            'best_accuracy': best_accuracy,
            'num_classes': num_classes,
            'class_names': train_dataset.classes
        }
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(model_out_path), exist_ok=True)
        
        # Save model
        torch.save(best_model_state_dict, model_out_path)
        
        # Also save checkpoint for easier loading
        checkpoint_path = model_out_path.replace('.pth', '_checkpoint.pth')
        torch.save(checkpoint, checkpoint_path)
        
        logger.info(f"Model saved to {model_out_path}")
        logger.info(f"Checkpoint saved to {checkpoint_path}")
        
        return best_accuracy, None
    
    except Exception as e:
        logger.error(f"Error during training: {str(e)}")
        logger.error(traceback.format_exc())
        raise e

def generate_training_charts(metrics, output_dir, epochs_completed):
    """Generate charts to visualize training progress"""
    try:
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        logger.info(f"Saving charts to directory: {os.path.abspath(output_dir)}")
        
        import matplotlib
        matplotlib.use('Agg')  # Non-interactive backend
        import matplotlib.pyplot as plt
        
        # Create figure with 2 subplots
        plt.figure(figsize=(12, 10))
        
        # Plot 1: Training and Validation Loss
        plt.subplot(2, 1, 1)
        plt.plot(metrics['train_losses'], label='Training Loss')
        plt.plot(metrics['val_losses'], label='Validation Loss')
        plt.xlabel('Epoch')
        plt.ylabel('Loss')
        plt.title('Training and Validation Loss')
        plt.legend()
        plt.grid(True)
        
        # Plot 2: Training and Validation Accuracy
        plt.subplot(2, 1, 2)
        plt.plot(metrics['train_accuracies'], label='Training Accuracy')
        plt.plot(metrics['val_accuracies'], label='Validation Accuracy')
        plt.xlabel('Epoch')
        plt.ylabel('Accuracy (%)')
        plt.title('Training and Validation Accuracy')
        plt.legend()
        plt.grid(True)
        
        # Adjust layout
        plt.tight_layout()
        
        # Save chart
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = os.path.join(output_dir, f"training_chart_epoch_{epochs_completed}.png")
        plt.savefig(output_path, dpi=100)
        plt.close()
        
        # Also create a learning rate chart
        plt.figure(figsize=(10, 5))
        plt.plot(metrics['lr_history'])
        plt.xlabel('Iteration')
        plt.ylabel('Learning Rate')
        plt.title('Learning Rate Schedule')
        plt.grid(True)
        
        lr_output_path = os.path.join(output_dir, f"lr_chart_epoch_{epochs_completed}.png")
        plt.savefig(lr_output_path, dpi=100)
        plt.close()
        
        return output_path
    except Exception as e:
        logger.error(f"Error generating charts: {str(e)}")
        return None

def update_progress(status, progress, current_epoch=0, total_epochs=0, train_accuracy=0, val_accuracy=0, best_accuracy=0, train_loss=0, val_loss=0, current_batch=0, total_batches=0, batch_loss=0, batch_accuracy=0, message=None):
    """Update the training progress file and broadcast to WebSocket clients"""
    try:
        # Create progress data
        progress_data = {
            "type": "progress",
            "data": {
                "status": status,
                "progress": progress,
                "metrics": {
                    "current_epoch": current_epoch,
                    "total_epochs": total_epochs,
                    "train_accuracy": train_accuracy,
                    "val_accuracy": val_accuracy,
                    "best_accuracy": best_accuracy,
                    "train_loss": train_loss,
                    "val_loss": val_loss,
                    "current_batch": current_batch,
                    "total_batches": total_batches,
                    "batch_loss": batch_loss,
                    "batch_accuracy": batch_accuracy
                },
                "message": message
            }
        }

        # Update progress file
        os.makedirs("training_progress", exist_ok=True)
        with open("training_progress/cnn_training_progress.json", "w") as f:
            json.dump(progress_data, f)

        # Send to WebSocket
        ws_logger._send_to_websocket(progress_data)

    except Exception as e:
        logger.error(f"Error updating progress: {str(e)}")

def parse_args():
    parser = argparse.ArgumentParser(description='Train EfficientNet-B3 for fish classification.')
    parser.add_argument('--data_dir', type=str, default='app/datasets/fish_images', help='Directory for dataset')
    parser.add_argument('--model_out_path', type=str, default='app/models/trained_models/efficientnet_b3_fish_classifier.pth', help='Path to save the trained model')
    parser.add_argument('--num_classes', type=int, help='Number of classes in the dataset')
    parser.add_argument('--batch_size', type=int, default=16, help='Batch size for training')
    parser.add_argument('--epochs', type=int, default=50, help='Number of training epochs')
    parser.add_argument('--image_size', type=int, default=300, help='Input image size for EfficientNet-B3')
    return parser.parse_args()

def main():
    args = parse_args()

    # Configuration
    DATA_DIR = args.data_dir
    MODEL_OUT_PATH = args.model_out_path
    NUM_CLASSES = args.num_classes if args.num_classes else len(os.listdir(os.path.join(DATA_DIR, 'train')))
    BATCH_SIZE = args.batch_size
    EPOCHS = args.epochs
    IMAGE_SIZE = args.image_size
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    logger.info(f"Using device: {DEVICE}")

    # Image transformations
    data_transforms = {
        'train': transforms.Compose([
            transforms.RandomResizedCrop(IMAGE_SIZE),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3),
            transforms.RandomRotation(15),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406],
                                 [0.229, 0.224, 0.225])
        ]),
        'val': transforms.Compose([
            transforms.Resize(320),
            transforms.CenterCrop(IMAGE_SIZE),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406],
                                 [0.229, 0.224, 0.225])
        ])
    }

    # Load datasets with error handling
    try:
        image_datasets = {
            x: datasets.ImageFolder(os.path.join(DATA_DIR, x), data_transforms[x])
            for x in ['train', 'val']
        }
    except Exception as e:
        logger.error(f"Error loading datasets: {e}")
        return

    dataloaders = {
        'train': DataLoader(image_datasets['train'], batch_size=BATCH_SIZE, shuffle=True, num_workers=4, pin_memory=True),
        'val': DataLoader(image_datasets['val'], batch_size=BATCH_SIZE, shuffle=False, num_workers=4, pin_memory=True)
    }

    # Load pretrained EfficientNet-B3
    model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.4),
        nn.Linear(model.classifier[1].in_features, NUM_CLASSES)
    )
    model = model.to(DEVICE)

    # Optimizer and scheduler
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.0001, weight_decay=1e-5)
    scheduler = CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-6)

    # Training loop
    for epoch in range(EPOCHS):
        logger.info(f"\nEpoch {epoch + 1}/{EPOCHS}")
        for phase in ['train', 'val']:
            model.train() if phase == 'train' else model.eval()

            running_loss = 0.0
            running_corrects = 0

            for inputs, labels in dataloaders[phase]:
                inputs = inputs.to(DEVICE)
                labels = labels.to(DEVICE)
                optimizer.zero_grad()

                with torch.set_grad_enabled(phase == 'train'):
                    outputs = model(inputs)
                    _, preds = torch.max(outputs, 1)
                    loss = criterion(outputs, labels)
                    if phase == 'train':
                        loss.backward()
                        optimizer.step()

                running_loss += loss.item() * inputs.size(0)
                running_corrects += torch.sum(preds == labels.data)

            epoch_loss = running_loss / len(image_datasets[phase])
            epoch_acc = running_corrects.double() / len(image_datasets[phase])
            logger.info(f"{phase.capitalize()} Loss: {epoch_loss:.4f} Acc: {epoch_acc:.2%}")

            if phase == 'val':
                scheduler.step()

def debug_efficientnet():
    """Debug an unmodified EfficientNet to see how it processes data"""
    try:
        # Create a vanilla EfficientNet model
        model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
        model.eval()
        
        # Show its structure
        logger.info("Original EfficientNet-B3 structure:")
        logger.info(f"Features: {model.features}")
        logger.info(f"Classifier: {model.classifier}")
        
        # Create a dummy input
        dummy_input = torch.randn(1, 3, 224, 224)
        
        # Trace through its forward pass
        logger.info("Tracing EfficientNet forward pass...")
        
        # Features
        features_output = model.features(dummy_input)
        logger.info(f"Features output shape: {features_output.shape}")
        
        # Examine the _forward_impl method in the EfficientNet class
        # This should be: return self.classifier(self.features(x))
        logger.info("EfficientNet's forward implementation expects classifier to handle pooling")
        
        # Based on the implementation, the model can't be modified to use a custom classifier
        # structure unless it includes all the necessary operations
        logger.info("Recommendation: Only replace the final Linear layer in the classifier")
        
        return True
    except Exception as e:
        logger.error(f"Error during EfficientNet debugging: {str(e)}")
        logger.error(traceback.format_exc())
        return False

def create_model(num_classes):
    """Create a simplified EfficientNet-B3 model that avoids shape issues"""
    # Debug EfficientNet first to understand its structure
    debug_efficientnet()
    
    # Load pretrained model - use DEFAULT weights to ensure compatibility
    model = efficientnet_b3(weights=EfficientNet_B3_Weights.DEFAULT)
    
    # We'll freeze most parameters and only fine-tune the last few layers
    for param in model.parameters():
        param.requires_grad = False
        
    # Unfreeze the last 2 blocks of the backbone for fine-tuning
    for i, layer in enumerate(model.features):
        if i >= len(model.features) - 3:
            for param in layer.parameters():
                param.requires_grad = True
    
    # Log the original model structure
    logger.info(f"Original model structure:")
    logger.info(f"- Features: {type(model.features)}")
    logger.info(f"- Classifier: {model.classifier}")
    
    # Replace the classifier - only modify the final linear layer
    # This uses the original classifier structure that's known to work with EfficientNet
    num_ftrs = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(num_ftrs, num_classes)
    
    # Unfreeze the classifier parameters
    for param in model.classifier.parameters():
        param.requires_grad = True
        
    # Log the modified model structure
    logger.info(f"Modified model structure:")
    logger.info(f"- Features: {type(model.features)}")
    logger.info(f"- Classifier: {model.classifier}")
    logger.info(f"- Final layer shape: in={num_ftrs}, out={num_classes}")
    
    return model

def train_model(model, train_loader, val_loader, criterion, optimizer, scheduler, calibration_temperature=1.5, num_epochs=25, patience=10, device=None):
    """
    Train the CNN model
    
    Args:
        model: PyTorch model
        train_loader: DataLoader for training data
        val_loader: DataLoader for validation data
        criterion: Loss function
        optimizer: Optimizer
        scheduler: Learning rate scheduler
        calibration_temperature: Temperature for confidence calibration (higher = smoother)
        num_epochs: Maximum number of epochs
        patience: Early stopping patience in epochs
        device: Device to train on
        
    Returns:
        best_model_state_dict: State dict of the best model
        best_acc: Best validation accuracy
    """
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Initialize the GradScaler for mixed precision training - updated syntax
    if torch.cuda.is_available():
        scaler = torch.amp.GradScaler("cuda")
    else:
        scaler = torch.amp.GradScaler()
    
    # Set up early stopping
    early_stopping_counter = 0
    best_val_loss = float('inf')
    best_acc = 0.0
    best_model_state_dict = None
    
    # Gradient clipping norm
    max_grad_norm = 1.0
    
    # Check the model's architecture before training
    logger.info("Model architecture before training:")
    logger.info(f"Model type: {type(model).__name__}")
    logger.info(f"Classifier: {model.classifier}")
    
    # Check data dimensions in the first batch
    try:
        # Get a sample batch
        sample_inputs, sample_labels = next(iter(train_loader))
        logger.info(f"Sample batch shapes - inputs: {sample_inputs.shape}, labels: {sample_labels.shape}")
        
        # Test inference
        model.eval()
        with torch.no_grad():
            sample_outputs = model(sample_inputs.to(device))
            logger.info(f"Sample output shape: {sample_outputs.shape}")
        model.train()
    except Exception as e:
        logger.error(f"Error during model testing with sample batch: {str(e)}")
        logger.error(traceback.format_exc())
            
        # Use ResNet as a fallback - it's more robust to tensor shape issues
        logger.info("Falling back to ResNet18 which is more robust to shape issues")
        from torchvision.models import resnet18
        model = resnet18(weights=None)  # No pretrained weights
        num_classes = len(train_loader.dataset.classes)
        model.fc = nn.Linear(model.fc.in_features, num_classes)
        model = model.to(device)
        optimizer = optim.AdamW(model.parameters(), lr=1e-4)
    
    # Main training loop
    try:
        for epoch in range(num_epochs):
            # Training phase
            model.train()
            running_loss = 0.0
            correct = 0
            total = 0
            
            train_progress = tqdm(train_loader, desc=f'Epoch {epoch+1}/{num_epochs}')
            
            for i, (inputs, labels) in enumerate(train_progress):
                # Debug input shapes
                if i == 0:
                    logger.info(f"Training batch shape: inputs={inputs.shape}, labels={labels.shape}")
                    
                inputs, labels = inputs.to(device), labels.to(device)
                
                # Zero the parameter gradients
                optimizer.zero_grad()
                
                # Forward pass with autocasting
                with torch.amp.autocast(device_type=device.type if device.type == 'cuda' else 'cpu'):
                    # Debug model input
                    if i == 0:
                        logger.info(f"Inputs going into model: shape={inputs.shape}, device={inputs.device}")
                        # Check if any NaN values
                        if torch.isnan(inputs).any():
                            logger.error("NaN values detected in inputs!")
                    
                    try:
                        outputs = model(inputs)
                        loss = criterion(outputs, labels)
                    except RuntimeError as e:
                        logger.error(f"Error during forward pass: {str(e)}")
                        # More detailed debugging
                        try:
                            # Check if we can trace exactly where the shape mismatch happens
                            debug_x = inputs.clone()
                            logger.info(f"Input shape: {debug_x.shape}")
                            debug_x = model.features(debug_x)  # Run through backbone
                            logger.info(f"After backbone: {debug_x.shape}")
                            
                            # Debug each layer in classifier
                            for layer_idx, layer in enumerate(model.classifier):
                                try:
                                    debug_x = layer(debug_x)
                                    logger.info(f"After classifier layer {layer_idx} ({type(layer).__name__}): {debug_x.shape}")
                                except Exception as e2:
                                    logger.error(f"Error at classifier layer {layer_idx} ({type(layer).__name__}): {str(e2)}")
                                    break
                        except Exception as e3:
                            logger.error(f"Error during debugging: {str(e3)}")
                        
                        # Re-create the model to ensure correct architecture
                        logger.info("Attempting to recreate model with correct architecture...")
                        model = create_model(len(train_loader.dataset.classes)).to(device)
                        optimizer = optim.AdamW(model.parameters(), lr=1e-4)
                        scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=5)
                        continue  # Skip this batch
                
                # Backward and optimize with gradient scaling for mixed precision
                scaler.scale(loss).backward()
                
                # Clip gradients
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
                
                # Update weights
                scaler.step(optimizer)
                scaler.update()
                
                # Statistics
                running_loss += loss.item()
                _, predicted = outputs.max(1)
                total += labels.size(0)
                correct += predicted.eq(labels).sum().item()
                
                # Update progress bar
                if i % 10 == 0:  # Update every 10 batches
                    accuracy = 100. * correct / total if total > 0 else 0
                    train_progress.set_postfix({
                        'loss': running_loss / (i + 1),
                        'acc': f"{accuracy:.2f}%"
                    })
            
            # Calculate training metrics for this epoch
            train_loss = running_loss / len(train_loader)
            train_acc = 100. * correct / total if total > 0 else 0
            
            # Validation phase
            model.eval()
            val_loss = 0.0
            correct = 0
            total = 0
            
            class_correct = [0 for _ in range(len(train_loader.dataset.classes))]
            class_total = [0 for _ in range(len(train_loader.dataset.classes))]
            
            # No gradient computation for validation
            with torch.no_grad():
                for inputs, labels in val_loader:
                    inputs, labels = inputs.to(device), labels.to(device)
                    
                    # Forward pass
                    outputs = model(inputs)
                    loss = criterion(outputs, labels)
                    
                    # Apply temperature scaling for better calibration
                    if calibration_temperature != 1.0:
                        outputs = outputs / calibration_temperature
                    
                    # Statistics
                    val_loss += loss.item()
                    _, predicted = outputs.max(1)
                    total += labels.size(0)
                    correct += predicted.eq(labels).sum().item()
                    
                    # Per-class accuracy
                    correct_tensor = predicted.eq(labels)
                    for i in range(labels.size(0)):
                        label = labels[i].item()
                        class_correct[label] += correct_tensor[i].item()
                        class_total[label] += 1
            
            # Calculate validation metrics
            val_loss = val_loss / len(val_loader)
            val_acc = 100. * correct / total if total > 0 else 0
            
            # Calculate per class accuracy
            for i in range(len(train_loader.dataset.classes)):
                if class_total[i] > 0:
                    per_class_acc = 100 * class_correct[i] / class_total[i]
                    logger.info(f'Accuracy of {train_loader.dataset.classes[i]}: {per_class_acc:.2f}% ({class_correct[i]}/{class_total[i]})')
                else:
                    logger.info(f'Accuracy of {train_loader.dataset.classes[i]}: N/A (0/{class_total[i]})')
            
            # Scheduler step based on validation accuracy
            scheduler.step(val_acc)
            
            # Log the metrics
            logger.info(f'Epoch {epoch+1}/{num_epochs}, Train Loss: {train_loss:.4f}, Train Acc: {train_acc:.2f}%, '
                        f'Val Loss: {val_loss:.4f}, Val Acc: {val_acc:.2f}%')
            
            # Save checkpoint if better than previous best
            if val_acc > best_acc:
                logger.info(f'Validation Accuracy improved from {best_acc:.2f}% to {val_acc:.2f}%')
                best_acc = val_acc
                # Create a deep copy of the model to save the best state
                best_model_state_dict = copy.deepcopy(model.state_dict())
                
                # Reset early stopping counter
                early_stopping_counter = 0
            else:
                # Increment early stopping counter
                early_stopping_counter += 1
                logger.info(f'Validation Accuracy did not improve. Early stopping counter: {early_stopping_counter}/{patience}')
            
            # Early stopping
            if early_stopping_counter >= patience:
                logger.info(f'Early stopping triggered after {epoch+1} epochs')
                break
    
    except Exception as e:
        logger.error(f"Error during training: {str(e)}")
        logger.error(traceback.format_exc())
        logger.info("Training failed, but returning best model state if available")
    
    # Load best model
    if best_model_state_dict is not None:
        model.load_state_dict(best_model_state_dict)
    else:
        logger.warning("No best model state dict available, returning current model state")
        best_model_state_dict = model.state_dict()
    
    return best_model_state_dict, best_acc

def create_dataloaders(data_dir, image_size=224, batch_size=8, use_data_augmentation=True):
    """Create data loaders with proper weighting and augmentation
    
    Args:
        data_dir: Directory with the dataset
        image_size: Target image size
        batch_size: Batch size for training
        use_data_augmentation: Whether to use data augmentation
        
    Returns:
        train_loader: DataLoader for training data
        val_loader: DataLoader for validation data
        train_dataset: Training dataset
        num_classes: Number of classes in the dataset
    """
    # First prepare the dataset
    prepared_data_dir, num_classes = prepare_dataset(data_dir)
    logger.info(f"Dataset prepared with {num_classes} classes")
    
    # Define transforms
    if use_data_augmentation:
        train_transform = transforms.Compose([
            transforms.RandomResizedCrop(224, scale=(0.7, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomVerticalFlip(p=0.3),
            transforms.RandomRotation(45),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
            transforms.RandomAffine(degrees=20, translate=(0.1, 0.1), scale=(0.8, 1.2)),
            transforms.RandomPerspective(distortion_scale=0.4, p=0.5),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
            transforms.RandomErasing(p=0.3, scale=(0.02, 0.15))
        ])
    else:
        train_transform = transforms.Compose([
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])

    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    # Load the datasets
    train_dataset = WeightedImageFolder(
        root=os.path.join(prepared_data_dir, 'train'),
        transform=train_transform
    )
    
    val_dataset = datasets.ImageFolder(
        root=os.path.join(prepared_data_dir, 'val'),
        transform=val_transform
    )
    
    # Print dataset sizes
    logger.info(f"Training dataset: {len(train_dataset)} images")
    logger.info(f"Validation dataset: {len(val_dataset)} images")
    
    # Create weighted sampler for training
    if train_dataset.class_weights is not None:
        # Create sample weights based on class weights
        sample_weights = [train_dataset.class_weights[label] for _, label in train_dataset.samples]
        sampler = torch.utils.data.WeightedRandomSampler(
            weights=sample_weights,
            num_samples=len(train_dataset),
            replacement=True
        )
        shuffle = False  # Don't shuffle when using sampler
        logger.info("Using weighted sampler to handle class imbalance")
    else:
        sampler = None
        shuffle = True
        logger.info("Using standard random sampling (no class weights)")
    
    # Create data loaders with single process (num_workers=0) to avoid multiprocessing issues
    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        sampler=sampler,
        num_workers=0,  # Use single process
        pin_memory=torch.cuda.is_available(),
        drop_last=True  # Helps with batch normalization
    )
    
    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=0,  # Use single process
        pin_memory=torch.cuda.is_available()
    )
    
    return train_loader, val_loader, train_dataset, num_classes

if __name__ == "__main__":
    main()
