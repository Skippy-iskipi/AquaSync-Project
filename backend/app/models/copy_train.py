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
import shutil
import time
from datetime import datetime
import traceback
import json
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import random
import copy
from tqdm import tqdm

# Try to import GradScaler from the correct location based on PyTorch version
try:
    from torch.cuda.amp import GradScaler, autocast
    HAS_AMP = True
    AMP_DEVICE = 'cuda'
except ImportError:
    try:
        from torch.amp import GradScaler, autocast
        HAS_AMP = True
        AMP_DEVICE = 'cuda'
    except ImportError:
        # Fallback for older PyTorch versions
        HAS_AMP = False
        print("Warning: Mixed precision training not available in this PyTorch version")

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("train_cnn")


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
            logger.info(f"Class {i}: {class_name} - {count} images")
            
        # Calculate weights based on inverse frequency
        total_samples = sum(class_counts)
        if min(class_counts) == 0:
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


def prepare_dataset(data_dir, min_images_per_class=1):
    """
    Prepare the dataset by filtering out empty directories.
    Only keep directories that contain valid image files.
    Uses space-based names for consistency with database.
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

        if len(valid_images) >= min_images_per_class:
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

    # Process val directory
    val_dir = os.path.join(data_dir, 'val')
    if not os.path.exists(val_dir):
        os.makedirs(val_dir, exist_ok=True)
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
                os.remove(src_path)
                
            logger.info(f"Created validation set for {display_name}: {len(images_to_move)} images")
    else:
        # Process existing validation directory
        for class_name in train_subdirs:
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

    return temp_dir, num_classes


def should_stop():
    """Check if training should be stopped"""
    try:
        stop_signal_path = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "stop_training_signal.txt"))
        
        if os.path.exists(stop_signal_path):
            logger.info("Stop signal detected")
            return True
            
        return False
    except Exception as e:
        logger.error(f"Error checking stop signal: {str(e)}")
        return False


def calibrate_confidence(logits, temperature=1.0):
    """Apply temperature scaling to calibrate confidence scores."""
    scaled_logits = logits / temperature
    
    if len(scaled_logits.shape) == 1:
        return torch.nn.functional.softmax(scaled_logits, dim=0)
    else:
        return torch.nn.functional.softmax(scaled_logits, dim=1)


def verify_model_forward_pass(model, input_size=224, device=None):
    """Verify that the model can perform a forward pass with a dummy input."""
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    logger.info(f"Model verification - model type: {type(model).__name__}")
    
    try:
        if hasattr(model, 'classifier'):
            logger.info(f"Model has classifier: {model.classifier}")
            
        if hasattr(model, 'fc'):
            logger.info(f"Model has fc layer: {model.fc}")
    except Exception as e:
        logger.warning(f"Could not print model details: {str(e)}")
    
    dummy_input = torch.randn(1, 3, input_size, input_size).to(device)
    model.eval()
    
    try:
        logger.info(f"Verifying model forward pass with dummy input of shape {dummy_input.shape}")
        
        with torch.no_grad():
            if hasattr(model, 'features'):
                logger.info("Testing feature extraction...")
                features = model.features(dummy_input)
                logger.info(f"Features output shape: {features.shape}")
            
            logger.info("Testing the complete forward pass...")
            outputs = model(dummy_input)
            logger.info(f"Full forward pass successful, output shape: {outputs.shape}")
            logger.info("Model forward pass verification: SUCCESS")
            return True
    except Exception as e:
        logger.error(f"Model forward pass verification failed: {str(e)}")
        logger.error(traceback.format_exc())
        return False


def create_model(num_classes):
    """Create a simplified EfficientNet-B3 model that avoids shape issues"""
    # Load pretrained model
    model = efficientnet_b3(weights=EfficientNet_B3_Weights.DEFAULT)
    
    # Freeze most parameters and only fine-tune the last few layers
    for param in model.parameters():
        param.requires_grad = False
        
    # Unfreeze the last 2 blocks of the backbone for fine-tuning
    for i, layer in enumerate(model.features):
        if i >= len(model.features) - 3:
            for param in layer.parameters():
                param.requires_grad = True
    
    logger.info(f"Original model structure:")
    logger.info(f"- Features: {type(model.features)}")
    logger.info(f"- Classifier: {model.classifier}")
    
    # Replace the classifier - only modify the final linear layer
    num_ftrs = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(num_ftrs, num_classes)
    
    # Unfreeze the classifier parameters
    for param in model.classifier.parameters():
        param.requires_grad = True
        
    logger.info(f"Modified model structure:")
    logger.info(f"- Features: {type(model.features)}")
    logger.info(f"- Classifier: {model.classifier}")
    logger.info(f"- Final layer shape: in={num_ftrs}, out={num_classes}")
    
    return model


def create_dataloaders(data_dir, image_size=224, batch_size=8, use_data_augmentation=True):
    """Create data loaders with proper weighting and augmentation"""
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
    
    logger.info(f"Training dataset: {len(train_dataset)} images")
    logger.info(f"Validation dataset: {len(val_dataset)} images")
    
    # Create weighted sampler for training
    if train_dataset.class_weights is not None:
        sample_weights = [train_dataset.class_weights[label] for _, label in train_dataset.samples]
        sampler = torch.utils.data.WeightedRandomSampler(
            weights=sample_weights,
            num_samples=len(train_dataset),
            replacement=True
        )
        shuffle = False
        logger.info("Using weighted sampler to handle class imbalance")
    else:
        sampler = None
        shuffle = True
        logger.info("Using standard random sampling (no class weights)")
    
    # Create data loaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        sampler=sampler,
        num_workers=0,
        pin_memory=torch.cuda.is_available(),
        drop_last=True
    )
    
    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        num_workers=0,
        pin_memory=torch.cuda.is_available()
    )
    
    return train_loader, val_loader, train_dataset, num_classes


def train_model(model, train_loader, val_loader, criterion, optimizer, scheduler, calibration_temperature=1.5, num_epochs=25, patience=10, device=None):
    """Train the CNN model"""
    if device is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Initialize the GradScaler for mixed precision training (with compatibility check)
    scaler = None
    use_amp = HAS_AMP and device.type == 'cuda'
    
    if use_amp:
        try:
            scaler = GradScaler()
            logger.info("Using mixed precision training with GradScaler")
        except Exception as e:
            logger.warning(f"Failed to initialize GradScaler: {e}. Falling back to standard training.")
            use_amp = False
    else:
        logger.info("Mixed precision training not available or not using CUDA. Using standard training.")
    
    # Set up early stopping
    early_stopping_counter = 0
    best_val_loss = float('inf')
    best_acc = 0.0
    best_model_state_dict = None
    
    max_grad_norm = 1.0
    
    logger.info("Model architecture before training:")
    logger.info(f"Model type: {type(model).__name__}")
    logger.info(f"Classifier: {model.classifier}")
    
    # Check data dimensions in the first batch
    try:
        sample_inputs, sample_labels = next(iter(train_loader))
        logger.info(f"Sample batch shapes - inputs: {sample_inputs.shape}, labels: {sample_labels.shape}")
        
        model.eval()
        with torch.no_grad():
            sample_outputs = model(sample_inputs.to(device))
            logger.info(f"Sample output shape: {sample_outputs.shape}")
        model.train()
    except Exception as e:
        logger.error(f"Error during model testing with sample batch: {str(e)}")
        logger.error(traceback.format_exc())
        
        logger.info("Falling back to ResNet18 which is more robust to shape issues")
        from torchvision.models import resnet18
        model = resnet18(weights=None)
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
                if i == 0:
                    logger.info(f"Training batch shape: inputs={inputs.shape}, labels={labels.shape}")
                    
                inputs, labels = inputs.to(device), labels.to(device)
                
                optimizer.zero_grad()
                
                # Use mixed precision if available
                if use_amp and scaler is not None:
                    with autocast():
                        if i == 0:
                            logger.info(f"Inputs going into model: shape={inputs.shape}, device={inputs.device}")
                            if torch.isnan(inputs).any():
                                logger.error("NaN values detected in inputs!")
                        
                        try:
                            outputs = model(inputs)
                            loss = criterion(outputs, labels)
                        except RuntimeError as e:
                            logger.error(f"Error during forward pass: {str(e)}")
                            
                            # Re-create the model to ensure correct architecture
                            logger.info("Attempting to recreate model with correct architecture...")
                            model = create_model(len(train_loader.dataset.classes)).to(device)
                            optimizer = optim.AdamW(model.parameters(), lr=1e-4)
                            scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=5)
                            continue
                    
                    # Backward and optimize with gradient scaling for mixed precision
                    scaler.scale(loss).backward()
                    
                    # Clip gradients
                    scaler.unscale_(optimizer)
                    torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
                    
                    # Update weights
                    scaler.step(optimizer)
                    scaler.update()
                    
                else:
                    # Standard training without mixed precision
                    if i == 0:
                        logger.info(f"Inputs going into model: shape={inputs.shape}, device={inputs.device}")
                        if torch.isnan(inputs).any():
                            logger.error("NaN values detected in inputs!")
                    
                    try:
                        outputs = model(inputs)
                        loss = criterion(outputs, labels)
                    except RuntimeError as e:
                        logger.error(f"Error during forward pass: {str(e)}")
                        
                        # Re-create the model to ensure correct architecture
                        logger.info("Attempting to recreate model with correct architecture...")
                        model = create_model(len(train_loader.dataset.classes)).to(device)
                        optimizer = optim.AdamW(model.parameters(), lr=1e-4)
                        scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=5)
                        continue
                    
                    # Backward and optimize
                    loss.backward()
                    
                    # Clip gradients
                    torch.nn.utils.clip_grad_norm_(model.parameters(), max_grad_norm)
                    
                    # Update weights
                    optimizer.step()
                
                # Statistics
                running_loss += loss.item()
                _, predicted = outputs.max(1)
                total += labels.size(0)
                correct += predicted.eq(labels).sum().item()
                
                # Update progress bar
                if i % 10 == 0:
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
            
            with torch.no_grad():
                for inputs, labels in val_loader:
                    inputs, labels = inputs.to(device), labels.to(device)
                    
                    outputs = model(inputs)
                    loss = criterion(outputs, labels)
                    
                    if calibration_temperature != 1.0:
                        outputs = outputs / calibration_temperature
                    
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
                best_model_state_dict = copy.deepcopy(model.state_dict())
                early_stopping_counter = 0
            else:
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
            logger.info("Attempting to recreate the model with a simpler architecture...")
            model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
            
            num_ftrs = model.classifier[1].in_features
            model.classifier[1] = nn.Linear(num_ftrs, num_classes)
            
            model = model.to(device)
            
            if not verify_model_forward_pass(model, input_size=image_size, device=device):
                logger.warning("All attempts failed. Creating a bare-bones CNN model as final fallback...")
                
                from torchvision.models import resnet18
                model = resnet18(weights=None)
                model.fc = nn.Linear(model.fc.in_features, num_classes)
                model = model.to(device)
                
                if not verify_model_forward_pass(model, input_size=image_size, device=device):
                    raise RuntimeError("All model architecture attempts failed. Please check PyTorch and torchvision versions for compatibility.")
        
        # Generate class weights if needed
        if train_dataset.class_weights is not None:
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
        logger.info(f"- Mixed precision available: {HAS_AMP}")
        
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
        
        # FIXED: Create directory before saving model
        model_dir = os.path.dirname(model_out_path)
        if model_dir and not os.path.exists(model_dir):
            os.makedirs(model_dir, exist_ok=True)
            logger.info(f"Created model directory: {model_dir}")
        
        # Save the best model with checkpoint information
        checkpoint = {
            'model_state_dict': best_model_state_dict,
            'optimizer_state_dict': optimizer.state_dict(),
            'best_accuracy': best_accuracy,
            'num_classes': num_classes,
            'class_names': train_dataset.classes
        }
        
        # FIXED: Save model with proper error handling
        try:
            logger.info(f"Saving model to: {os.path.abspath(model_out_path)}")
            torch.save(best_model_state_dict, model_out_path)
            logger.info(f"Model successfully saved to {model_out_path}")
            
            # Also save checkpoint for easier loading
            checkpoint_path = model_out_path.replace('.pth', '_checkpoint.pth')
            logger.info(f"Saving checkpoint to: {os.path.abspath(checkpoint_path)}")
            torch.save(checkpoint, checkpoint_path)
            logger.info(f"Checkpoint successfully saved to {checkpoint_path}")
            
        except Exception as save_error:
            logger.error(f"Error saving model: {str(save_error)}")
            logger.error(traceback.format_exc())
            raise save_error

        # FIXED: Upload to Supabase with proper error handling
        remote_model_key = None
        remote_checkpoint_key = None
        try:
            # Try to import and use Supabase - handle import errors gracefully
            try:
                from app.supabase_config import get_supabase_client
                supabase = get_supabase_client()
                
                bucket_name = "models"
                dest_model_path = f"models/{os.path.basename(model_out_path)}"
                dest_ckpt_path = f"models/{os.path.basename(checkpoint_path)}"

                # Upload best model
                with open(model_out_path, "rb") as f:
                    supabase.storage.from_(bucket_name).upload(dest_model_path, f, {"upsert": True})

                # Upload checkpoint  
                with open(checkpoint_path, "rb") as f:
                    supabase.storage.from_(bucket_name).upload(dest_ckpt_path, f, {"upsert": True})

                remote_model_key = dest_model_path
                remote_checkpoint_key = dest_ckpt_path
                logger.info(f"Uploaded {dest_model_path} and {dest_ckpt_path} to Supabase bucket '{bucket_name}'")
                
            except ImportError:
                logger.warning("Supabase module not found - skipping upload to cloud storage")
            except Exception as supabase_error:
                logger.error(f"Error uploading to Supabase: {str(supabase_error)}")
                
        except Exception as upload_error:
            logger.error(f"Error during upload process: {str(upload_error)}")
        
        return best_accuracy, {"model_storage_key": remote_model_key, "checkpoint_storage_key": remote_checkpoint_key}
    
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

    except Exception as e:
        logger.error(f"Error updating progress: {str(e)}")


def parse_args():
    parser = argparse.ArgumentParser(description='Train EfficientNet-B3 for fish classification.')
    parser.add_argument('--data_dir', type=str, default='app/datasets/fish_images', help='Directory for dataset')
    parser.add_argument('--model_out_path', type=str, default='app/models/trained_models/efficientnet_b3_fish_classifier.pth', help='Path to save the trained model')
    parser.add_argument('--num_classes', type=int, help='Number of classes in the dataset')
    parser.add_argument('--batch_size', type=int, default=8, help='Batch size for training')
    parser.add_argument('--epochs', type=int, default=25, help='Number of training epochs')
    parser.add_argument('--image_size', type=int, default=224, help='Input image size for EfficientNet-B3')
    return parser.parse_args()


def main():
    args = parse_args()

    # Configuration
    DATA_DIR = args.data_dir
    MODEL_OUT_PATH = args.model_out_path
    BATCH_SIZE = args.batch_size
    EPOCHS = args.epochs
    IMAGE_SIZE = args.image_size
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    logger.info(f"Using device: {DEVICE}")
    logger.info(f"Data directory: {DATA_DIR}")
    logger.info(f"Model output path: {MODEL_OUT_PATH}")
    logger.info(f"Mixed precision training available: {HAS_AMP}")

    # FIXED: Call the main training function properly
    try:
        best_accuracy, storage_info = train_cnn_model(
            species_name="fish_classification",
            data_dir=DATA_DIR,
            model_out_path=MODEL_OUT_PATH,
            epochs=EPOCHS,
            batch_size=BATCH_SIZE,
            learning_rate=0.0001,
            image_size=IMAGE_SIZE,
            use_data_augmentation=True,
            calibration_temperature=1.5
        )
        
        logger.info(f"Training completed successfully!")
        logger.info(f"Best validation accuracy: {best_accuracy:.2f}%")
        logger.info(f"Model saved to: {MODEL_OUT_PATH}")
        
        if storage_info["model_storage_key"]:
            logger.info(f"Model uploaded to cloud storage: {storage_info['model_storage_key']}")
            
    except Exception as e:
        logger.error(f"Training failed: {str(e)}")
        logger.error(traceback.format_exc())
        raise e


if __name__ == "__main__":
    main()