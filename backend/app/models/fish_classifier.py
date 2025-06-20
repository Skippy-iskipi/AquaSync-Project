import os
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torchvision import transforms, models
from PIL import Image
import numpy as np
from sklearn.preprocessing import LabelEncoder
from typing import Tuple, List, Dict, Optional, Union
import logging
import matplotlib.pyplot as plt
import psutil
import time
import gc
from tqdm import tqdm
from functools import partial

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Check for GPU and set device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
logger.info(f"Using device: {device}")

if torch.cuda.is_available():
    logger.info(f"GPU: {torch.cuda.get_device_name(0)}")
    # Enable cuDNN auto-tuner
    torch.backends.cudnn.benchmark = True
    torch.backends.cudnn.enabled = True
    # Enable tensor cores for mixed precision training
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
else:
    # Get CPU info
    num_physical_cores = psutil.cpu_count(logical=False)
    num_logical_cores = psutil.cpu_count(logical=True)
    logger.info(f"CPU: Intel i5-12500H with {num_physical_cores} physical cores, {num_logical_cores} logical cores")
    torch.set_num_threads(num_logical_cores)
    logger.info(f"PyTorch using {torch.get_num_threads()} threads")

# Data augmentation transforms optimized for GPU
train_transforms = transforms.Compose([
    transforms.Resize((224, 224), interpolation=transforms.InterpolationMode.BILINEAR),
    transforms.RandomResizedCrop(224, scale=(0.7, 1.0)),  # Increased scale range
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomVerticalFlip(p=0.3),
    transforms.RandomRotation(30),
    transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
    transforms.RandomAffine(degrees=15, translate=(0.1, 0.1), scale=(0.8, 1.2)),
    transforms.RandomPerspective(distortion_scale=0.3, p=0.5),
    transforms.RandomErasing(p=0.2),  # Add random erasing for robustness
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

val_transforms = transforms.Compose([
    transforms.Resize((224, 224), interpolation=transforms.InterpolationMode.BILINEAR),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

class FishDataset(Dataset):
    def __init__(self, 
                 data_dir: str, 
                 csv_file: str, 
                 transform=None, 
                 split='train',
                 preload: bool = False,
                 preload_limit: int = 1000):
        """
        Initialize Fish Dataset
        
        Args:
            data_dir: Base directory containing images
            csv_file: Path to CSV with fish metadata
            transform: Image transformations to apply
            split: 'train', 'valid', or 'test'
            preload: Whether to preload images into memory
            preload_limit: Maximum number of images to preload
        """
        self.data_dir = os.path.join(data_dir, split)
        self.transform = transform
        self.preload = preload
        self.preloaded_images = {}
        
        logger.info(f"Initializing dataset for split: {split}")
        logger.info(f"Data directory: {self.data_dir}")
        
        self.df = pd.read_csv(csv_file)
        logger.info(f"Found {len(self.df)} entries in CSV file")
        
        # Clean data - preserve spaces in names
        self.df = self.df.dropna(subset=['Common name', 'Scientific name'])
        self.df['Common name'] = self.df['Common name'].str.strip()
        self.df['Scientific name'] = self.df['Scientific name'].str.strip()
        logger.info(f"After cleaning: {len(self.df)} entries")
        
        # Encode labels - using names exactly as they appear in database
        self.label_encoder = LabelEncoder()
        self.labels = self.label_encoder.fit_transform(self.df['Common name'])  # Changed to Common name
        self.common_to_scientific = dict(zip(self.df['Common name'], self.df['Scientific name']))
        
        # Find all valid images - use Common name for directories
        self.image_files = []
        self.class_counts = {}
        
        for label_idx, (_, row) in enumerate(self.df.iterrows()):
            common_name = row['Common name']  # Use Common name for directory matching
            
            if isinstance(common_name, str):
                label_dir = os.path.join(self.data_dir, common_name)
                
                if os.path.exists(label_dir):
                    image_files = [f for f in os.listdir(label_dir) 
                                   if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
                    
                    valid_images = []
                    for img_file in image_files:
                        img_path = os.path.join(label_dir, img_file)
                        try:
                            # Just check if image is valid without full loading
                            with Image.open(img_path) as img:
                                img.verify()
                            valid_images.append((img_path, label_idx, common_name))
                        except Exception as e:
                            logger.warning(f"Skipping corrupted image {img_path}: {str(e)}")
                    
                    if valid_images:
                        self.image_files.extend(valid_images)
                        self.class_counts[common_name] = len(valid_images)
                    else:
                        logger.warning(f"No valid images found in directory: {label_dir}")
                else:
                    logger.warning(f"Directory does not exist: {label_dir}")
        
        logger.info(f"Total: Successfully loaded {len(self.image_files)} valid images for {split} split")
        
        # Print class distribution summary
        logger.info("\nClass distribution summary:")
        class_counts = sorted(self.class_counts.items(), key=lambda x: x[1], reverse=True)
        for class_name, count in class_counts[:5]:
            logger.info(f"{class_name}: {count} images")
        if len(class_counts) > 5:
            logger.info(f"... and {len(class_counts)-5} more classes")
        
        if len(self.image_files) == 0:
            raise ValueError("No images found for the dataset.")
            
        # Calculate class weights for training
        if split == 'train':
            self.class_weights = self.calculate_class_weights()
        
        # Preload images if requested and dataset is small enough
        if preload and len(self.image_files) <= preload_limit:
            logger.info(f"Preloading {len(self.image_files)} images into memory...")
            for img_path, _, _ in tqdm(self.image_files):
                try:
                    with Image.open(img_path) as img:
                        # Store as RGB to ensure consistency
                        self.preloaded_images[img_path] = img.copy().convert('RGB')
                except Exception as e:
                    logger.error(f"Error preloading {img_path}: {str(e)}")
            logger.info(f"Preloaded {len(self.preloaded_images)} images")

    def calculate_class_weights(self) -> List[float]:
        """Calculate class weights to handle imbalance"""
        total_samples = sum(self.class_counts.values())
        num_classes = len(self.class_counts)
        
        weights = []
        for class_name in self.label_encoder.classes_:
            count = self.class_counts.get(class_name, 0)
            if count > 0:
                # Use square root to reduce weight disparity
                weight = np.sqrt(total_samples / (num_classes * count))
            else:
                weight = 1.0
            weights.append(weight)
        
        # Normalize weights
        weights = np.array(weights)
        weights = weights / weights.mean()
        
        return weights.tolist()

    def get_sampler(self):
        """Create weighted sampler for balanced training"""
        sample_weights = [0] * len(self.image_files)
        for idx, (_, label, _) in enumerate(self.image_files):
            sample_weights[idx] = self.class_weights[label]
            
        return WeightedRandomSampler(
            sample_weights, 
            len(sample_weights), 
            replacement=True
        )

    def __len__(self) -> int:
        return len(self.image_files)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int, str]:
        img_path, label_idx, common_name = self.image_files[idx]
        
        try:
            # Use preloaded image if available
            if img_path in self.preloaded_images:
                image = self.preloaded_images[img_path]
            else:
                image = Image.open(img_path).convert('RGB')
                
            if self.transform:
                image = self.transform(image)
                
            return image, label_idx, common_name
            
        except Exception as e:
            logger.error(f"Error loading image {img_path}: {str(e)}")
            # Fallback to next image if current is corrupt
            new_idx = (idx + 1) % len(self)
            return self.__getitem__(new_idx)

    def get_num_classes(self) -> int:
        return len(self.label_encoder.classes_)

    def get_class_names(self) -> List[str]:
        return self.label_encoder.classes_.tolist()

class LightweightFishClassifier(nn.Module):
    """Mobile-optimized classifier with efficient architectures"""
    def __init__(self, num_classes: int, model_name: str = 'mobilenet_v3_large'):
        super(LightweightFishClassifier, self).__init__()
        
        self.num_classes = num_classes
        
        if model_name == 'mobilenet_v3_large':
            # MobileNetV3-Large with improved head
            self.model = models.mobilenet_v3_large(weights='DEFAULT')
            num_ftrs = self.model.classifier[-1].in_features
            
            # Enhanced classifier head
            self.model.classifier = nn.Sequential(
                nn.Linear(num_ftrs, 1024),
                nn.BatchNorm1d(1024),
                nn.ReLU(inplace=True),
                nn.Dropout(p=0.3),
                nn.Linear(1024, 512),
                nn.BatchNorm1d(512),
                nn.ReLU(inplace=True),
                nn.Dropout(p=0.2),
                nn.Linear(512, num_classes)
            )
            
        elif model_name == 'efficientnet_lite0':
            # EfficientNet-Lite0 - Designed for mobile
            self.model = models.efficientnet_b0(weights='DEFAULT')  # Base for lite version
            num_ftrs = self.model.classifier[1].in_features
            self.model.classifier = nn.Sequential(
                nn.Dropout(p=0.2),
                nn.Linear(num_ftrs, num_classes)
            )
            
        elif model_name == 'mobilenet_v2':
            # MobileNetV2 - Proven mobile architecture
            self.model = models.mobilenet_v2(weights='DEFAULT')
            num_ftrs = self.model.classifier[-1].in_features
            self.model.classifier[-1] = nn.Linear(num_ftrs, num_classes)
            
        elif model_name == 'shufflenet_v2_x1_0':
            # ShuffleNetV2 - Very efficient for mobile
            self.model = models.shufflenet_v2_x1_0(weights='DEFAULT')
            num_ftrs = self.model.fc.in_features
            self.model.fc = nn.Sequential(
                nn.Dropout(p=0.2),
                nn.Linear(num_ftrs, num_classes)
            )
            
        else:
            raise ValueError(f"Unsupported model: {model_name}")

    def forward(self, x):
        return self.model(x)

def train_model(model: nn.Module, 
                train_loader: DataLoader,
                val_loader: DataLoader,
                device: torch.device,
                num_epochs: int = 50,  # Increased epochs
                patience: int = 10,    # Increased patience
                checkpoint_dir: str = 'models'):
    """Train model with improved training strategy"""
    
    # Use label smoothing loss for better generalization
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    criterion = criterion.to(device)
    
    # Use AdamW with cosine annealing
    optimizer = optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=0.001,
        weight_decay=0.01,
        betas=(0.9, 0.999)
    )
    
    # Cosine annealing scheduler with warm restarts
    scheduler = optim.lr_scheduler.CosineAnnealingWarmRestarts(
        optimizer,
        T_0=10,  # Restart every 10 epochs
        T_mult=2, # Double the restart interval after each restart
        eta_min=1e-6
    )
    
    # Initialize tracking variables
    best_val_acc = 0.0
    best_epoch = 0
    epochs_without_improvement = 0
    
    history = {
        'train_loss': [],
        'train_acc': [],
        'val_loss': [],
        'val_acc': [],
        'lr': []
    }
    
    # Training loop
    for epoch in range(num_epochs):
        gc.collect()
        if device.type == 'cuda':
            torch.cuda.empty_cache()
        
        # Log memory usage
        if device.type == 'cuda':
            memory_stats = torch.cuda.memory_stats()
            logger.info(f"GPU Memory allocated: {memory_stats['allocated_bytes.all.current'] / 1024**2:.2f} MB")
        
        start_time = time.time()
        
        # Training phase
        model.train()
        train_loss = 0.0
        train_correct = 0
        train_total = 0
        
        train_progress = tqdm(train_loader, desc=f"Epoch {epoch+1}/{num_epochs} [Train]")
        
        for batch in train_progress:
            inputs, labels = batch[0].to(device), batch[1].to(device)
            
            optimizer.zero_grad()
            
            # Regular forward pass without mixed precision
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            # Update metrics
            train_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            train_total += labels.size(0)
            train_correct += (predicted == labels).sum().item()
            
            train_progress.set_postfix({
                'loss': f"{loss.item():.4f}",
                'acc': f"{100 * train_correct / train_total:.2f}%"
            })
        
        # Calculate average training metrics
        avg_train_loss = train_loss / len(train_loader)
        train_acc = 100 * train_correct / train_total
        
        # Validation phase
        model.eval()
        val_loss = 0.0
        val_correct = 0
        val_total = 0
        
        val_progress = tqdm(val_loader, desc=f"Epoch {epoch+1}/{num_epochs} [Valid]")
        
        with torch.no_grad():
            for inputs, labels, _ in val_progress:
                inputs, labels = inputs.to(device), labels.to(device)
                outputs = model(inputs)
                loss = criterion(outputs, labels)
                
                val_loss += loss.item()
                _, predicted = torch.max(outputs.data, 1)
                val_total += labels.size(0)
                val_correct += (predicted == labels).sum().item()
                
                val_progress.set_postfix({
                    'loss': f"{loss.item():.4f}",
                    'acc': f"{100 * val_correct / val_total:.2f}%"
                })
        
        # Calculate average validation metrics
        avg_val_loss = val_loss / len(val_loader)
        val_acc = 100 * val_correct / val_total
        
        # Update learning rate based on validation accuracy
        scheduler.step()
        
        # Record metrics
        history['train_loss'].append(avg_train_loss)
        history['train_acc'].append(train_acc)
        history['val_loss'].append(avg_val_loss)
        history['val_acc'].append(val_acc)
        history['lr'].append(optimizer.param_groups[0]['lr'])
        
        # Log results
        epoch_time = time.time() - start_time
        logger.info(f"Epoch {epoch+1}/{num_epochs} completed in {epoch_time/60:.2f} minutes")
        logger.info(f"Train Loss: {avg_train_loss:.4f}, Train Acc: {train_acc:.2f}%")
        logger.info(f"Val Loss: {avg_val_loss:.4f}, Val Acc: {val_acc:.2f}%")
        logger.info(f"Learning Rate: {optimizer.param_groups[0]['lr']:.6f}")
        
        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_epoch = epoch
            epochs_without_improvement = 0
            
            # Ensure directory exists
            os.makedirs(checkpoint_dir, exist_ok=True)
            
            # Save model state
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_acc': val_acc,
                'train_acc': train_acc,
            }, os.path.join(checkpoint_dir, 'best_fish_classifier.pth'))
            
            logger.info(f"Saved new best model with validation accuracy: {val_acc:.2f}%")
        else:
            epochs_without_improvement += 1
            
        # Early stopping check
        if epochs_without_improvement >= patience:
            logger.info(f"Early stopping triggered after {epoch+1} epochs")
            logger.info(f"Best validation accuracy: {best_val_acc:.2f}% at epoch {best_epoch+1}")
            break
    
    # Plot training history
    plot_training_history(history, os.path.join(checkpoint_dir, 'plots'))
    
    # Load best model for return
    checkpoint = torch.load(os.path.join(checkpoint_dir, 'best_fish_classifier.pth'))
    model.load_state_dict(checkpoint['model_state_dict'])
    
    return model, checkpoint['train_acc'], checkpoint['val_acc']

def plot_training_history(history: Dict[str, List], save_dir: str):
    """Plot and save training metrics"""
    os.makedirs(save_dir, exist_ok=True)
    
    plt.figure(figsize=(12, 9))
    
    # Plot loss
    plt.subplot(2, 2, 1)
    plt.plot(history['train_loss'], label='Train Loss')
    plt.plot(history['val_loss'], label='Validation Loss')
    plt.title('Loss over epochs')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.legend()
    
    # Plot accuracy
    plt.subplot(2, 2, 2)
    plt.plot(history['train_acc'], label='Train Accuracy')
    plt.plot(history['val_acc'], label='Validation Accuracy')
    plt.title('Accuracy over epochs')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy (%)')
    plt.legend()
    
    # Plot learning rate
    plt.subplot(2, 2, 3)
    plt.plot(history['lr'])
    plt.title('Learning Rate over epochs')
    plt.xlabel('Epoch')
    plt.ylabel('Learning Rate')
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, 'training_history.png'))
    plt.close()

def load_trained_model(model_path: str, num_classes: int, model_name: str = 'mobilenet_v3_large') -> nn.Module:
    """Load a trained model from checkpoint"""
    model = LightweightFishClassifier(num_classes, model_name=model_name)
    checkpoint = torch.load(model_path, map_location=torch.device('cpu'))
    model.load_state_dict(checkpoint['model_state_dict'])
    return model

def predict(model, image_tensor, class_names, top_k=5):
    """
    Make predictions using the trained model.
    
    Args:
        model: Trained PyTorch model
        image_tensor: Preprocessed image tensor
        class_names: List of class names (with spaces, in Title Case)
        top_k: Number of top predictions to return
        
    Returns:
        List of tuples (class_name, probability)
    """
    model.eval()
    with torch.no_grad():
        # Add batch dimension and move to device
        image_tensor = image_tensor.unsqueeze(0)
        if torch.cuda.is_available():
            image_tensor = image_tensor.cuda()
            model = model.cuda()
        
        # Get model predictions
        outputs = model(image_tensor)
        probabilities = torch.nn.functional.softmax(outputs, dim=1)
        
        # Get top k predictions
        topk_probs, topk_indices = torch.topk(probabilities, top_k)
        
        # Convert to Python lists
        predictions = []
        for i in range(top_k):
            idx = topk_indices[0][i].item()
            prob = topk_probs[0][i].item()
            # Use class names exactly as they appear in database (with spaces)
            predictions.append((class_names[idx], prob))
    
    return predictions

def main():
    # Set fixed random seed for reproducibility
    torch.manual_seed(42)
    np.random.seed(42)
    if torch.cuda.is_available():
        torch.cuda.manual_seed(42)
    
    # Base directories
    base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dataset_path = os.path.join(base_path, 'datasets', 'dataset', 'dataset')
    csv_path = os.path.join(base_path, 'datasets', 'fish.csv')
    output_path = os.path.join(base_path, 'backend', 'app')
    
    # Create output directories
    os.makedirs(os.path.join(output_path, 'models'), exist_ok=True)
    os.makedirs(os.path.join(output_path, 'plots'), exist_ok=True)

    # Define checkpoint directory
    checkpoint_dir = os.path.join(output_path, 'models')

    logger.info(f"Dataset path: {dataset_path}")
    logger.info(f"CSV path: {csv_path}")
    logger.info(f"Output path: {output_path}")

    # Optimize batch sizes for mobile models
    if torch.cuda.is_available():
        train_batch_size = 16  
        val_batch_size = 16    
        worker_count = min(2, os.cpu_count() or 1)  # Reduced from 4
        pin_memory = True
    else:
        train_batch_size = 8  
        val_batch_size = 8    
        worker_count = min(1, os.cpu_count() or 1)  # Reduced from 2
        pin_memory = False
    
    # Try to preload small datasets (only if under 250 images)
    preload_limit = 250
    
    # Create datasets - maintaining original directory structure
    train_dataset = FishDataset(
        dataset_path, 
        csv_file=csv_path, 
        transform=train_transforms, 
        split='train',
        preload=False,  # Ensure preloading is disabled
        preload_limit=preload_limit
    )
    
    val_dataset = FishDataset(
        dataset_path, 
        csv_file=csv_path, 
        transform=val_transforms, 
        split='valid',
        preload=False,  # Ensure preloading is disabled
        preload_limit=preload_limit
    )

    # Get class info
    num_classes = train_dataset.get_num_classes()
    class_names = train_dataset.get_class_names()
    logger.info(f"Training with {num_classes} classes")

    # Get weighted sampler for balanced training
    train_sampler = train_dataset.get_sampler()

    # Create data loaders with optimized parameters
    train_loader = DataLoader(
        train_dataset, 
        batch_size=train_batch_size,
        sampler=train_sampler,
        num_workers=worker_count,
        pin_memory=pin_memory,
        prefetch_factor=2,
        persistent_workers=True
    )

    val_loader = DataLoader(
        val_dataset, 
        batch_size=val_batch_size,
        shuffle=False, 
        num_workers=worker_count,
        pin_memory=pin_memory,
        prefetch_factor=2,
        persistent_workers=True
    )

    # Initialize mobile-optimized model
    logger.info(f"Initializing MobileNetV3-Large model for {device}")
    model = LightweightFishClassifier(num_classes, model_name='mobilenet_v3_large').to(device)
    
    # Log model size
    model_size = sum(p.numel() * p.element_size() for p in model.parameters()) / (1024 * 1024)
    logger.info(f"Model size: {model_size:.2f} MB")
    
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    logger.info(f"Model has {trainable_params:,} trainable parameters")

    # Train with mobile-optimized settings
    model, train_accuracy, val_accuracy = train_model(
        model, 
        train_loader, 
        val_loader, 
        device,
        num_epochs=50,  # Balanced for mobile
        patience=10,
        checkpoint_dir=checkpoint_dir
    )
    
    # Quantize model for mobile deployment
    if device.type == 'cuda':
        model.eval()
        model_quantized = torch.quantization.convert(model.to('cpu'), inplace=False)
        
        # Save quantized model
        torch.save({
            'model_state_dict': model_quantized.state_dict(),
            'val_acc': val_accuracy,
            'train_acc': train_accuracy,
        }, os.path.join(checkpoint_dir, 'best_fish_classifier_quantized.pth'))
        
        # Log quantized model size
        quantized_size = sum(p.numel() * p.element_size() for p in model_quantized.parameters()) / (1024 * 1024)
        logger.info(f"Quantized model size: {quantized_size:.2f} MB")
    
    logger.info(f"Training complete!")
    logger.info(f"Final Training Accuracy: {train_accuracy:.2f}%")
    logger.info(f"Final Validation Accuracy: {val_accuracy:.2f}%")

if __name__ == "__main__":
    main()
