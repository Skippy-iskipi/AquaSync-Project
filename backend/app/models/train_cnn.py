import os
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import torchvision.transforms.functional as TF
from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights, efficientnet_b3, EfficientNet_B3_Weights, efficientnet_b2, EfficientNet_B2_Weights
from torch.utils.data import DataLoader, Subset
from pathlib import Path
import logging
import argparse
import shutil
import time
from datetime import datetime
import traceback
import torch.nn.functional as F
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import random
import copy
from tqdm import tqdm
import gc
import numpy as np

# ----------------------------
# GPU & AMP configuration
# ----------------------------
import torch.backends.cudnn as cudnn
cudnn.benchmark = True
cudnn.deterministic = False

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
        HAS_AMP = False
        print("Warning: Mixed precision training not available in this PyTorch version")

# Memory management utilities
def clear_gpu_cache():
    """Clear GPU cache to free up memory"""
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        gc.collect()

def get_gpu_memory_info():
    """Get current GPU memory usage"""
    if torch.cuda.is_available():
        allocated = torch.cuda.memory_allocated() / 1024**3
        reserved = torch.cuda.memory_reserved() / 1024**3
        return allocated, reserved
    return 0, 0

# ----------------------------
# Logging
# ----------------------------
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("train_cnn")

# ============================
# Enhanced Dataset Processing for Large Scale
# ============================
class LargeScaleImageFolder(datasets.ImageFolder):
    def __init__(self, root, transform=None, min_samples_per_class=5):
        """
        Enhanced ImageFolder that handles large number of classes better
        """
        super(LargeScaleImageFolder, self).__init__(root=root, transform=transform)
        self.min_samples_per_class = min_samples_per_class
        self.class_weights = None
        self.original_class_count = len(self.classes)
        self._filter_classes()
        self._compute_class_weights()
        
    def _filter_classes(self):
        """Filter classes while keeping as many as possible"""
        class_counts = {}
        for _, label in self.samples:
            class_counts[label] = class_counts.get(label, 0) + 1
        
        # Use more lenient filtering for large datasets
        classes_to_keep = {label for label, count in class_counts.items() 
                          if count >= max(3, self.min_samples_per_class)}
        
        # If still too restrictive, gradually reduce requirements
        while len(classes_to_keep) < self.original_class_count * 0.8 and self.min_samples_per_class > 3:
            self.min_samples_per_class = max(3, self.min_samples_per_class - 1)
            classes_to_keep = {label for label, count in class_counts.items() 
                              if count >= self.min_samples_per_class}
        
        # Filter samples and update mappings
        self.samples = [(path, label) for path, label in self.samples if label in classes_to_keep]
        
        # Create new class mapping
        old_to_new = {old_label: new_label for new_label, old_label in enumerate(sorted(classes_to_keep))}
        self.samples = [(path, old_to_new[label]) for path, label in self.samples]
        
        # Update class names
        old_classes = self.classes
        self.classes = [old_classes[old_label] for old_label in sorted(classes_to_keep)]
        
        logger.info(f"Dataset: kept {len(self.classes)}/{self.original_class_count} classes "
                   f"with >= {self.min_samples_per_class} samples each")
        
    def _compute_class_weights(self):
        """Compute balanced weights for large number of classes"""
        class_counts = [0] * len(self.classes)
        for _, label in self.samples:
            class_counts[label] += 1
            
        # Log class distribution summary
        min_samples = min(class_counts)
        max_samples = max(class_counts)
        avg_samples = sum(class_counts) / len(class_counts)
        
        logger.info(f"Class distribution: min={min_samples}, max={max_samples}, avg={avg_samples:.1f}")
            
        total_samples = sum(class_counts)
        if min(class_counts) == 0:
            self.class_weights = None
            logger.warning("Some classes have 0 samples. Not using class weights.")
            return
            
        # Use more aggressive balancing for large datasets
        weights = torch.FloatTensor([
            (total_samples / (len(self.classes) * count)) ** 0.7 if count > 0 else 0
            for count in class_counts
        ])
        
        # Cap weights to prevent extreme values
        weights = torch.clamp(weights, 0.1, 5.0)
        self.class_weights = weights
        
        logger.info(f"Class weights: min={weights.min():.2f}, max={weights.max():.2f}, mean={weights.mean():.2f}")


class CurriculumLearningDataset:
    """Implements curriculum learning for better training with many classes"""
    
    def __init__(self, dataset, initial_classes_ratio=0.3):
        self.full_dataset = dataset
        self.current_classes = None
        self.current_indices = None
        self.initial_classes_ratio = initial_classes_ratio
        self.stage = 0
        
        # Group samples by class
        self.class_to_indices = {}
        for idx, (_, label) in enumerate(dataset.samples):
            if label not in self.class_to_indices:
                self.class_to_indices[label] = []
            self.class_to_indices[label].append(idx)
        
        # Start with easier classes (more samples)
        self._update_curriculum()
    
    def _update_curriculum(self):
        """Update the curriculum to include more classes"""
        class_sizes = [(label, len(indices)) for label, indices in self.class_to_indices.items()]
        class_sizes.sort(key=lambda x: x[1], reverse=True)  # Sort by size descending
        
        if self.stage == 0:
            # Stage 1: Start with classes that have the most samples (easier)
            n_classes = max(10, int(len(class_sizes) * self.initial_classes_ratio))
        elif self.stage == 1:
            # Stage 2: Add medium-sized classes
            n_classes = max(30, int(len(class_sizes) * 0.6))
        else:
            # Stage 3: Include all classes
            n_classes = len(class_sizes)
        
        selected_classes = [label for label, _ in class_sizes[:n_classes]]
        
        # Collect all indices for selected classes
        selected_indices = []
        for label in selected_classes:
            selected_indices.extend(self.class_to_indices[label])
        
        self.current_classes = selected_classes
        self.current_indices = selected_indices
        
        logger.info(f"Curriculum stage {self.stage + 1}: using {len(selected_classes)} classes, "
                   f"{len(selected_indices)} samples")
    
    def advance_stage(self):
        """Advance to next curriculum stage"""
        self.stage += 1
        self._update_curriculum()
        return len(self.current_classes) < len(self.class_to_indices)
    
    def get_subset(self):
        """Get current curriculum subset"""
        return Subset(self.full_dataset, self.current_indices)


def prepare_large_scale_dataset(data_dir, min_images_per_class=5, val_split=0.15):
    """
    Prepare dataset optimized for large number of classes
    """
    if not os.path.exists(data_dir):
        raise FileNotFoundError(f"Dataset directory '{data_dir}' does not exist")

    temp_dir = os.path.join(os.path.dirname(data_dir), 'temp_large_dataset_' + os.path.basename(data_dir))
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)

    train_temp = os.path.join(temp_dir, 'train')
    val_temp = os.path.join(temp_dir, 'val')
    os.makedirs(train_temp, exist_ok=True)
    os.makedirs(val_temp, exist_ok=True)

    valid_extensions = ('.jpg', '.jpeg', '.png', '.ppm', '.bmp', '.pgm', '.tif', '.tiff', '.webp')
    
    train_dir = os.path.join(data_dir, 'train')
    if not os.path.exists(train_dir):
        raise FileNotFoundError(f"Training directory '{train_dir}' does not exist")

    # Collect class information
    class_info = {}
    train_subdirs = [d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))]
    
    for class_name in train_subdirs:
        class_dir = os.path.join(train_dir, class_name)
        valid_images = [f for f in os.listdir(class_dir)
                       if os.path.isfile(os.path.join(class_dir, f)) and
                       f.lower().endswith(valid_extensions)]
        
        if len(valid_images) >= min_images_per_class:
            class_info[class_name] = {
                'images': valid_images,
                'path': class_dir,
                'count': len(valid_images)
            }

    logger.info(f"Found {len(class_info)} classes with >= {min_images_per_class} images")

    if len(class_info) < 50:
        logger.warning("Dataset has fewer than 50 classes - consider using standard training")

    # Create splits with smaller validation sets for large datasets
    for class_name, info in class_info.items():
        images = info['images'].copy()
        random.shuffle(images)
        
        total_images = len(images)
        # Use smaller validation split for large datasets to maximize training data
        val_count = max(2, min(int(total_images * val_split), total_images // 5))
        train_count = total_images - val_count
        
        train_images = images[:train_count]
        val_images = images[train_count:]
        
        # Create directories and copy images
        train_class_dir = os.path.join(train_temp, class_name)
        val_class_dir = os.path.join(val_temp, class_name)
        os.makedirs(train_class_dir, exist_ok=True)
        os.makedirs(val_class_dir, exist_ok=True)
        
        for img in train_images:
            shutil.copy2(os.path.join(info['path'], img), os.path.join(train_class_dir, img))
        
        for img in val_images:
            shutil.copy2(os.path.join(info['path'], img), os.path.join(val_class_dir, img))

    num_classes = len(class_info)
    logger.info(f"Prepared dataset with {num_classes} classes")
    
    return temp_dir, num_classes
# Advanced Model Architecture for Large Scale
# ============================
class LargeScaleEfficientNet(nn.Module):
    """Enhanced EfficientNet for large-scale classification"""
    
    def __init__(self, num_classes, architecture='b2', dropout_rate=0.3, use_mixup=True, use_pretrained=True):
        super(LargeScaleEfficientNet, self).__init__()
        
        self.use_mixup = use_mixup
        
        # Choose more powerful architecture for large datasets
        # Control pretrained weights to avoid downloads during inference
        if architecture == 'b0':
            self.backbone = efficientnet_b0(weights=EfficientNet_B0_Weights.DEFAULT if use_pretrained else None)
            features_dim = 1280
        elif architecture == 'b2':
            self.backbone = efficientnet_b2(weights=EfficientNet_B2_Weights.DEFAULT if use_pretrained else None)
            features_dim = 1408
        elif architecture == 'b3':
            self.backbone = efficientnet_b3(weights=EfficientNet_B3_Weights.DEFAULT if use_pretrained else None)
            features_dim = 1536
        else:
            raise ValueError(f"Unsupported architecture: {architecture}")
        
        # More conservative transfer learning for large datasets
        self._setup_transfer_learning(architecture, num_classes)
        
        # Remove original classifier
        self.backbone.classifier = nn.Identity()
        
        # Enhanced classifier for large number of classes
        self.classifier = self._build_classifier(features_dim, num_classes, dropout_rate)
        
        # Initialize weights
        self._initialize_weights()
    
    def _setup_transfer_learning(self, architecture, num_classes):
        """Setup transfer learning based on number of classes"""
        # Freeze more layers for large datasets to prevent overfitting
        if num_classes > 80:
            # Freeze most layers, only fine-tune the last few
            freeze_until = len(self.backbone.features) - 2
        elif num_classes > 50:
            freeze_until = len(self.backbone.features) - 3
        else:
            freeze_until = len(self.backbone.features) - 4
        
        # Freeze backbone layers
        for i, layer in enumerate(self.backbone.features):
            if i < freeze_until:
                for param in layer.parameters():
                    param.requires_grad = False
            else:
                for param in layer.parameters():
                    param.requires_grad = True
        
        logger.info(f"Frozen layers: 0-{freeze_until-1}, unfrozen: {freeze_until}-{len(self.backbone.features)-1}")
    
    def _build_classifier(self, features_dim, num_classes, dropout_rate):
        return nn.Sequential(
            nn.Dropout(dropout_rate),
            nn.Linear(features_dim, features_dim // 2),
            nn.BatchNorm1d(features_dim // 2),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout_rate * 0.5),
            nn.Linear(features_dim // 2, features_dim // 4),
            nn.BatchNorm1d(features_dim // 4),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout_rate * 0.3),
            nn.Linear(features_dim // 4, num_classes)
        )

    
    def _initialize_weights(self):
        """Enhanced weight initialization"""
        for m in self.classifier.modules():
            if isinstance(m, nn.Linear):
                nn.init.normal_(m.weight, 0, 0.01)
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
    
    def forward(self, x):
        # Get feature maps before pooling
        features = self.backbone.features(x)
        # Global average pooling to [B, C, 1, 1]
        features = F.adaptive_avg_pool2d(features, 1)
        # Flatten to [B, C]
        features = torch.flatten(features, 1)
        # Classifier
        return self.classifier(features)



def create_large_scale_model(num_classes, architecture='b2', dropout_rate=0.3, device=None, use_pretrained=True):
    """Create model optimized for large-scale classification
    
    use_pretrained: whether to initialize the EfficientNet backbone with torchvision pretrained weights.
    Set to False during inference to avoid network downloads.
    """
    model = LargeScaleEfficientNet(
        num_classes=num_classes,
        architecture=architecture,
        dropout_rate=dropout_rate,
        use_mixup=True,
        use_pretrained=use_pretrained
    ).to(device)
    
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total_params = sum(p.numel() for p in model.parameters())
    logger.info(f"Large-scale EfficientNet-{architecture.upper()} created:")
    logger.info(f"- Total parameters: {total_params:,}")
    logger.info(f"- Trainable parameters: {trainable_params:,} ({100*trainable_params/total_params:.1f}%)")
    
    return model


def train_large_scale_cnn(species_name, data_dir, model_out_path, epochs=40, batch_size=16,
                         learning_rate=0.0005, image_size=260, architecture='b2',
                         dropout_rate=0.3, min_samples_per_class=5, use_curriculum=False):
    """
    Main training function optimized for large number of classes (80+ classes)
    """
    
    try:
        clear_gpu_cache()
        
        # Create data loaders
        train_loader, val_loader, train_dataset, num_classes = create_large_scale_dataloaders(
            data_dir=data_dir,
            image_size=image_size,
            batch_size=batch_size,
            min_samples_per_class=min_samples_per_class
        )
        
        logger.info(f"Large-scale training setup: {num_classes} classes")
        
        if num_classes < 50:
            logger.warning("Consider using standard training for datasets with < 50 classes")
        
        # Device setup
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        logger.info(f"Using device: {device}")
        
        # Create model
        model = create_large_scale_model(
            num_classes=num_classes,
            architecture=architecture,
            dropout_rate=dropout_rate,
            device=device,
            use_pretrained=True  # training benefits from pretrained weights
        )
        
        # Enhanced loss function for large datasets
        if train_dataset.class_weights is not None:
            # Use smoother class weights to prevent over-correction
            smoothed_weights = torch.sqrt(train_dataset.class_weights).to(device)
            criterion = nn.CrossEntropyLoss(weight=smoothed_weights, label_smoothing=0.1)
            logger.info("Using weighted CrossEntropyLoss with label smoothing")
        else:
            criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
        
        # Optimized optimizer for large datasets
        backbone_params = [p for n, p in model.named_parameters() if 'classifier' not in n and p.requires_grad]
        classifier_params = [p for n, p in model.named_parameters() if 'classifier' in n and p.requires_grad]
        
        optimizer = optim.AdamW([
            {'params': backbone_params, 'lr': learning_rate * 0.05, 'weight_decay': 0.05},  # Very low LR for backbone
            {'params': classifier_params, 'lr': learning_rate, 'weight_decay': 0.01}
        ])
        
        # Multi-step scheduler for long training
        scheduler = optim.lr_scheduler.MultiStepLR(
            optimizer, milestones=[epochs//3, 2*epochs//3], gamma=0.3
        )
        
        # Training configuration
        logger.info("=== LARGE-SCALE TRAINING CONFIGURATION ===")
        logger.info(f"- Architecture: EfficientNet-{architecture.upper()}")
        logger.info(f"- Classes: {num_classes}")
        logger.info(f"- Training samples: {len(train_dataset)}")
        logger.info(f"- Batch size: {batch_size}")
        logger.info(f"- Image size: {image_size}x{image_size}")
        logger.info(f"- Epochs: {epochs}")
        logger.info(f"- Backbone LR: {learning_rate * 0.05:.7f}")
        logger.info(f"- Classifier LR: {learning_rate:.6f}")
        logger.info(f"- Dropout rate: {dropout_rate}")
        
        # Training loop
        best_val_acc = 0.0
        best_model_state = None
        patience = 12  # Higher patience for large datasets
        early_stopping_counter = 0
        
        use_amp = HAS_AMP and device.type == 'cuda'
        
        train_losses = []
        val_losses = []
        train_accuracies = []
        val_accuracies = []
        
        logger.info("Starting large-scale training...")
        
        for epoch in range(epochs):
            # Training
            train_loss, train_acc = train_epoch_large_scale(
                model, train_loader, criterion, optimizer, device, 
                use_mixup=True, use_amp=use_amp, epoch=epoch
            )
            
            # Validation
            val_loss, val_acc, class_acc, good_classes, poor_classes = validate_epoch_large_scale(
                model, val_loader, criterion, device, num_classes
            )
            
            # Store metrics
            train_losses.append(train_loss)
            val_losses.append(val_loss)
            train_accuracies.append(train_acc)
            val_accuracies.append(val_acc)
            
            # Scheduler step
            scheduler.step()
            
            # Logging
            current_lr = optimizer.param_groups[1]['lr']  # Classifier LR
            logger.info(f'Epoch {epoch+1}/{epochs}:')
            logger.info(f'  Train - Loss: {train_loss:.4f}, Acc: {train_acc:.2f}%')
            logger.info(f'  Val   - Loss: {val_loss:.4f}, Acc: {val_acc:.2f}%')
            logger.info(f'  Classes performing well (>70%): {good_classes}/{num_classes}')
            logger.info(f'  Classes performing poorly (<30%): {poor_classes}/{num_classes}')
            logger.info(f'  Learning Rate: {current_lr:.7f}')
            
            # Model improvement check
            if val_acc > best_val_acc:
                best_val_acc = val_acc
                best_model_state = copy.deepcopy(model.state_dict())
                early_stopping_counter = 0
                logger.info(f'  ✓ New best validation accuracy: {val_acc:.2f}%')
            else:
                early_stopping_counter += 1
                logger.info(f'  No improvement. Early stopping: {early_stopping_counter}/{patience}')
            
            # Early stopping for large datasets
            if early_stopping_counter >= patience:
                logger.info(f'Early stopping triggered after {epoch+1} epochs')
                break
            
            # Memory cleanup
            if epoch % 3 == 0:
                clear_gpu_cache()
            
            # Progress report every 10 epochs
            if (epoch + 1) % 10 == 0:
                analyze_large_scale_progress(class_acc, num_classes, epoch + 1)

        # Load best model
        if best_model_state is not None:
            model.load_state_dict(best_model_state)
            logger.info(f"Loaded best model with accuracy: {best_val_acc:.2f}%")

        # Save model and checkpoint
        model_dir = os.path.dirname(model_out_path)
        if model_dir and not os.path.exists(model_dir):
            os.makedirs(model_dir, exist_ok=True)
        
        # Enhanced checkpoint for large-scale models
        training_history = {
            'train_losses': train_losses,
            'val_losses': val_losses,
            'train_accuracies': train_accuracies,
            'val_accuracies': val_accuracies
        }
        
        checkpoint = {
            'model_state_dict': best_model_state,
            'optimizer_state_dict': optimizer.state_dict(),
            'best_accuracy': best_val_acc,
            'num_classes': num_classes,
            'class_names': train_dataset.classes,
            'training_history': training_history,
            'model_config': {
                'architecture': f'efficientnet_{architecture}',
                'image_size': image_size,
                'batch_size': batch_size,
                'dropout_rate': dropout_rate,
                'min_samples_per_class': min_samples_per_class,
                'large_scale_optimized': True
            }
        }
        
        logger.info(f"Saving model to: {model_out_path}")
        torch.save(best_model_state, model_out_path)
        
        checkpoint_path = model_out_path.replace('.pth', '_checkpoint.pth')
        logger.info(f"Saving checkpoint to: {checkpoint_path}")
        torch.save(checkpoint, checkpoint_path)
        
        # Cloud upload attempt
        remote_model_key = None
        remote_checkpoint_key = None
        try:
            from app.supabase_config import get_supabase_client
            supabase = get_supabase_client()
            
            bucket_name = "models"
            dest_model_path = f"models/{os.path.basename(model_out_path)}"
            dest_ckpt_path = f"models/{os.path.basename(checkpoint_path)}"

            with open(model_out_path, "rb") as f:
                supabase.storage.from_(bucket_name).upload(dest_model_path, f, {"upsert": True})
            with open(checkpoint_path, "rb") as f:
                supabase.storage.from_(bucket_name).upload(dest_ckpt_path, f, {"upsert": True})

            remote_model_key = dest_model_path
            remote_checkpoint_key = dest_ckpt_path
            logger.info("Successfully uploaded to cloud storage")
            
        except Exception as e:
            logger.warning(f"Cloud upload skipped: {str(e)}")
        
        clear_gpu_cache()
        
        # Final analysis
        analyze_large_scale_results(training_history, best_val_acc, num_classes, 
                                  good_classes, poor_classes)
        
        return best_val_acc, {
            "model_storage_key": remote_model_key,
            "checkpoint_storage_key": remote_checkpoint_key,
            "training_history": training_history,
            "num_classes": num_classes
        }
    
    except Exception as e:
        logger.error(f"Large-scale training failed: {str(e)}")
        logger.error(traceback.format_exc())
        clear_gpu_cache()
        raise


def analyze_large_scale_progress(class_accuracies, num_classes, epoch):
    """Analyze progress during large-scale training"""
    if len(class_accuracies) == 0:
        return
    
    excellent = (class_accuracies >= 90).sum().item()
    good = ((class_accuracies >= 70) & (class_accuracies < 90)).sum().item()
    fair = ((class_accuracies >= 50) & (class_accuracies < 70)).sum().item()
    poor = (class_accuracies < 50).sum().item()
    
    logger.info(f"=== EPOCH {epoch} CLASS PERFORMANCE ===")
    logger.info(f"🟢 Excellent (≥90%): {excellent} classes ({100*excellent/num_classes:.1f}%)")
    logger.info(f"🟡 Good (70-89%): {good} classes ({100*good/num_classes:.1f}%)")
    logger.info(f"🟠 Fair (50-69%): {fair} classes ({100*fair/num_classes:.1f}%)")
    logger.info(f"🔴 Poor (<50%): {poor} classes ({100*poor/num_classes:.1f}%)")


def analyze_large_scale_results(training_history, best_accuracy, num_classes, good_classes, poor_classes):
    """Enhanced analysis for large-scale training results"""
    if not training_history or len(training_history['train_accuracies']) < 3:
        return
    
    train_acc = training_history['train_accuracies']
    val_acc = training_history['val_accuracies']
    
    final_train_acc = train_acc[-1]
    final_val_acc = val_acc[-1]
    acc_gap = final_train_acc - final_val_acc
    
    logger.info("=== LARGE-SCALE TRAINING ANALYSIS ===")
    logger.info(f"📊 Final Results:")
    logger.info(f"  - Training Accuracy: {final_train_acc:.2f}%")
    logger.info(f"  - Validation Accuracy: {final_val_acc:.2f}%")
    logger.info(f"  - Best Validation Accuracy: {best_accuracy:.2f}%")
    logger.info(f"  - Train-Val Gap: {acc_gap:.2f}%")
    logger.info(f"  - Total Classes: {num_classes}")
    logger.info(f"  - Classes >70% acc: {good_classes}/{num_classes} ({100*good_classes/num_classes:.1f}%)")
    logger.info(f"  - Classes <30% acc: {poor_classes}/{num_classes} ({100*poor_classes/num_classes:.1f}%)")
    
    # Specialized recommendations for large datasets
    logger.info("📋 Large-Scale Recommendations:")
    
    if best_accuracy < 50:
        logger.warning("🔴 VERY LOW ACCURACY for large dataset:")
        logger.warning("  1. Consider hierarchical classification approach")
        logger.warning("  2. Group similar classes together")
        logger.warning("  3. Increase min_samples_per_class to 15+")
        logger.warning("  4. Use EfficientNet-B3 or larger model")
        logger.warning("  5. Implement progressive training (few classes first)")
    
    elif best_accuracy < 65:
        logger.info("🟡 MODERATE ACCURACY for large dataset:")
        logger.info("  1. Extend training to 50-70 epochs")
        logger.info("  2. Use stronger regularization (dropout 0.4+)")
        logger.info("  3. Implement focal loss for hard examples")
        logger.info("  4. Consider self-supervised pretraining")
        logger.info("  5. Add more data augmentation")
    
    else:
        logger.info("🟢 GOOD ACCURACY for large dataset!")
        if good_classes < num_classes * 0.7:
            logger.info("  - Focus on improving worst-performing classes")
            logger.info("  - Consider class-specific augmentation")
    
    # Overfitting/Underfitting analysis for large datasets
    if abs(acc_gap) > 25:
        if acc_gap > 0:
            logger.warning("⚠️ STRONG OVERFITTING (common with many classes):")
            logger.warning("  - Increase dropout to 0.4-0.5")
            logger.warning("  - Use stronger regularization")
            logger.warning("  - Reduce model complexity")
            logger.warning("  - Implement curriculum learning")
        else:
            logger.warning("⚠️ UNDERFITTING:")
            logger.warning("  - Use larger model (EfficientNet-B3+)")
            logger.warning("  - Train for more epochs")
            logger.warning("  - Increase learning rate")
    
    # Class balance recommendations
    if poor_classes > num_classes * 0.3:
        logger.warning("⚠️ MANY POORLY PERFORMING CLASSES:")
        logger.warning("  - Implement focal loss")
        logger.warning("  - Use class-balanced sampling")
        logger.warning("  - Consider two-stage training")
        logger.warning("  - Collect more data for worst classes")
    
    logger.info("=== END LARGE-SCALE ANALYSIS ===")


def get_optimal_large_scale_config():
    """Get configuration optimized for large number of classes"""
    config = {
        'batch_size': 16,
        'image_size': 260,
        'architecture': 'b2',
        'epochs': 40,
        'learning_rate': 0.0005,
        'dropout_rate': 0.3,
        'min_samples_per_class': 5,
        'use_curriculum': False
    }
    
    if torch.cuda.is_available():
        gpu_memory_gb = torch.cuda.get_device_properties(0).total_memory / 1024**3
        gpu_name = torch.cuda.get_device_properties(0).name
        
        logger.info(f"Large-scale GPU optimization: {gpu_name} ({gpu_memory_gb:.1f}GB)")
        
        if gpu_memory_gb >= 12:  # High-end GPUs
            config.update({
                'batch_size': 20,
                'image_size': 288,
                'architecture': 'b3',
                'epochs': 50
            })
        elif gpu_memory_gb >= 8:  # Mid-range GPUs
            config.update({
                'batch_size': 16,
                'image_size': 260,
                'architecture': 'b2',
                'epochs': 45
            })
        else:  # Lower-end GPUs
            config.update({
                'batch_size': 12,
                'image_size': 224,
                'architecture': 'b0',
                'dropout_rate': 0.4  # Higher regularization for smaller models
            })
    else:
        # CPU training (not recommended for large datasets)
        config.update({
            'batch_size': 4,
            'image_size': 224,
            'epochs': 30,
            'architecture': 'b0'
        })
        logger.warning("CPU training not recommended for large datasets (109 classes)")
    
    logger.info(f"Large-scale optimized config: {config}")
    return config


def should_stop():
    """Check if training should be stopped"""
    try:
        stop_signal_path = os.path.abspath(os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 
            "stop_training_signal.txt"
        ))
        if os.path.exists(stop_signal_path):
            logger.info("Stop signal detected")
            return True
        return False
    except Exception as e:
        logger.error(f"Error checking stop signal: {str(e)}")
        return False


# ============================
# CLI Interface for Large Scale
# ============================
def parse_large_scale_args():
    parser = argparse.ArgumentParser(
        description='Train EfficientNet for Large-Scale Fish Classification (80+ classes)'
    )
    parser.add_argument('--data_dir', type=str, 
                       default='app/datasets/fish_images', 
                       help='Dataset directory')
    parser.add_argument('--model_out_path', type=str, 
                       default='app/models/trained_models/efficientnet_fish_classifier.pth',
                       help='Output path for trained model')
    parser.add_argument('--batch_size', type=int, default=None, 
                       help='Batch size (auto-detected if not specified)')
    parser.add_argument('--epochs', type=int, default=40, 
                       help='Number of training epochs')
    parser.add_argument('--image_size', type=int, default=None, 
                       help='Input image size (auto-detected if not specified)')
    parser.add_argument('--architecture', type=str, choices=['b0', 'b2', 'b3'], default=None,
                       help='EfficientNet architecture (auto-detected if not specified)')
    parser.add_argument('--dropout_rate', type=float, default=0.3, 
                       help='Dropout rate')
    parser.add_argument('--learning_rate', type=float, default=0.0005, 
                       help='Learning rate')
    parser.add_argument('--min_samples_per_class', type=int, default=5,
                       help='Minimum samples per class to include')
    parser.add_argument('--use_curriculum', action='store_true',
                       help='Use curriculum learning (start with fewer classes)')
    parser.add_argument('--force_large_scale', action='store_true',
                       help='Force large-scale training even for smaller datasets')
    return parser.parse_args()


def main():
    args = parse_large_scale_args()
    
    # Get large-scale optimized settings
    optimal_config = get_optimal_large_scale_config()
    
    batch_size = args.batch_size or optimal_config['batch_size']
    image_size = args.image_size or optimal_config['image_size']
    architecture = args.architecture or optimal_config['architecture']
    epochs = optimal_config['epochs'] if args.epochs == 40 else args.epochs

    logger.info("=== LARGE-SCALE FISH CLASSIFICATION TRAINING ===")
    logger.info("🎯 Goal: Handle 80+ classes with minimal overfitting")
    logger.info("🎯 Expected accuracy: 60-80% (excellent for 100+ classes)")
    logger.info(f"💻 Hardware: {'GPU' if torch.cuda.is_available() else 'CPU'}")
    
    if torch.cuda.is_available():
        gpu_props = torch.cuda.get_device_properties(0)
        logger.info(f"📱 GPU: {gpu_props.name} ({gpu_props.total_memory / 1024**3:.1f}GB)")

    try:
        best_accuracy, results = train_large_scale_cnn(
            species_name="efficientnet_fish_classifier",
            data_dir=args.data_dir,
            model_out_path=args.model_out_path,
            epochs=epochs,
            batch_size=batch_size,
            learning_rate=args.learning_rate,
            image_size=image_size,
            architecture=architecture,
            dropout_rate=args.dropout_rate,
            min_samples_per_class=args.min_samples_per_class,
            use_curriculum=args.use_curriculum
        )
        
        num_classes = results['num_classes']
        
        logger.info("🎉 LARGE-SCALE TRAINING COMPLETED!")
        logger.info(f"🏆 Best Accuracy: {best_accuracy:.2f}%")
        logger.info(f"📊 Total Classes: {num_classes}")
        logger.info(f"💾 Model saved: {args.model_out_path}")
        
        if results.get("model_storage_key"):
            logger.info(f"☁️ Cloud backup: {results['model_storage_key']}")
        
        # Success evaluation for large datasets
        if num_classes >= 100:
            if best_accuracy >= 70:
                logger.info("🌟 EXCELLENT! Outstanding performance for 100+ classes!")
            elif best_accuracy >= 60:
                logger.info("👍 VERY GOOD! Great performance for large dataset!")
            elif best_accuracy >= 50:
                logger.info("👌 GOOD! Reasonable performance for many classes.")
            else:
                logger.warning("⚠️ Below expectations - see recommendations above.")
        elif num_classes >= 80:
            if best_accuracy >= 75:
                logger.info("🌟 EXCELLENT! Great performance for 80+ classes!")
            elif best_accuracy >= 65:
                logger.info("👍 VERY GOOD! Good performance for large dataset!")
            else:
                logger.warning("⚠️ Room for improvement - check recommendations.")
        else:
            logger.info("ℹ️ Consider standard training for datasets with < 80 classes")
            
    except Exception as e:
        logger.error(f"❌ Large-scale training failed: {str(e)}")
        logger.error("💡 Try reducing batch_size, using smaller architecture, or curriculum learning")
        raise


if __name__ == "__main__":
    main()