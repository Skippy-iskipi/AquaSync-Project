import os
import shutil
import random
import logging
import hashlib
import argparse
from pathlib import Path
from PIL import Image, ImageStat, ImageEnhance
from collections import defaultdict
import json
import numpy as np

# ==============================
# Setup logging
# ==============================
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("preprocess_dataset")

# ==============================
# Enhanced Configuration for All Classes
# ==============================
class LargeScaleDatasetConfig:
    def __init__(self):
        self.raw_dir = "app/datasets/raw_fish_images"
        self.output_dir = "app/datasets/fish_images"
        
        # Optimized split ratios for large datasets
        self.train_ratio = 0.80  # More data for training with many classes
        self.val_ratio = 0.15    # Adequate validation
        self.test_ratio = 0.05   # Smaller test set to maximize training data
        
        # Keep ALL classes strategy
        self.min_images_per_class = 3     # Very low threshold to keep all classes
        self.max_classes = None           # No limit - keep all classes
        self.target_image_size = (288, 288)  # Larger images for better feature learning
        self.quality_threshold = 20       # Lower threshold to keep more images
        
        # File handling
        self.supported_extensions = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".tif", ".webp"}
        self.max_file_size_mb = 100       # Allow larger files
        self.min_file_size_kb = 2         # Lower minimum to keep more images
        
        # Processing options optimized for large datasets
        self.remove_duplicates = True
        self.resize_images = True
        self.quality_check = True
        self.consolidate_similar_classes = False  # Keep original classes
        self.augment_small_classes = True         # NEW: Augment classes with few samples
        self.balance_dataset = True               # NEW: Balance the dataset
        
        # Data augmentation for small classes
        self.augmentation_threshold = 10  # Classes with < 10 images get augmented
        self.target_samples_per_class = 15  # Target number after augmentation


def calculate_image_hash(image_path):
    """Calculate perceptual hash for duplicate detection"""
    try:
        with Image.open(image_path) as img:
            img = img.convert('L').resize((8, 8))
            pixels = list(img.getdata())
            avg = sum(pixels) / len(pixels)
            hash_bits = ''.join('1' if pixel > avg else '0' for pixel in pixels)
            return hash_bits
    except Exception:
        return None


def assess_image_quality(image_path):
    """Assess image quality - more lenient for large datasets"""
    try:
        with Image.open(image_path) as img:
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            width, height = img.size
            if width < 32 or height < 32:
                return 0  # Too small
            
            # More lenient quality assessment
            gray = img.convert('L')
            img_array = np.array(gray)
            
            # Simple sharpness metric
            grad_x = np.diff(img_array, axis=1)
            grad_y = np.diff(img_array, axis=0)
            sharpness = np.var(grad_x) + np.var(grad_y)
            
            # More lenient scoring
            quality_score = min(100, max(20, sharpness / 50))
            
            return quality_score
            
    except Exception as e:
        logger.warning(f"Quality assessment failed for {image_path}: {e}")
        return 30  # Default score


def create_augmented_images(image_path, output_dir, base_name, num_augmentations=5):
    """Create augmented images for classes with few samples"""
    augmented_paths = []
    
    try:
        with Image.open(image_path) as img:
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            for i in range(num_augmentations):
                aug_img = img.copy()
                
                # Apply random augmentations
                # Random rotation
                if random.random() < 0.7:
                    angle = random.uniform(-15, 15)
                    aug_img = aug_img.rotate(angle, expand=False, fillcolor=(128, 128, 128))
                
                # Random brightness
                if random.random() < 0.5:
                    factor = random.uniform(0.8, 1.2)
                    enhancer = ImageEnhance.Brightness(aug_img)
                    aug_img = enhancer.enhance(factor)
                
                # Random contrast
                if random.random() < 0.5:
                    factor = random.uniform(0.8, 1.2)
                    enhancer = ImageEnhance.Contrast(aug_img)
                    aug_img = enhancer.enhance(factor)
                
                # Random color
                if random.random() < 0.3:
                    factor = random.uniform(0.9, 1.1)
                    enhancer = ImageEnhance.Color(aug_img)
                    aug_img = enhancer.enhance(factor)
                
                # Horizontal flip
                if random.random() < 0.5:
                    aug_img = aug_img.transpose(Image.FLIP_LEFT_RIGHT)
                
                # Save augmented image
                aug_filename = f"{base_name}_aug_{i:02d}.jpg"
                aug_path = os.path.join(output_dir, aug_filename)
                aug_img.save(aug_path, 'JPEG', quality=95)
                augmented_paths.append(aug_path)
                
    except Exception as e:
        logger.error(f"Failed to create augmented images for {image_path}: {e}")
    
    return augmented_paths


class LargeScaleDatasetProcessor:
    def __init__(self, config):
        self.config = config
        self.stats = defaultdict(int)
        self.class_info = {}
        self.duplicate_hashes = set()
        
    def validate_image(self, image_path):
        """Enhanced but lenient image validation for large datasets"""
        try:
            # Check file size
            file_size = image_path.stat().st_size
            if file_size < self.config.min_file_size_kb * 1024:
                self.stats['too_small'] += 1
                return False, "File too small"
            if file_size > self.config.max_file_size_mb * 1024 * 1024:
                self.stats['too_large'] += 1
                return False, "File too large"
            
            # Check if image can be opened
            with Image.open(image_path) as img:
                img.verify()
                
            # Reopen for further checks
            with Image.open(image_path) as img:
                width, height = img.size
                if width < 24 or height < 24:  # Very lenient
                    self.stats['resolution_too_low'] += 1
                    return False, "Resolution too low"
                
                # Duplicate check
                if self.config.remove_duplicates:
                    img_hash = calculate_image_hash(image_path)
                    if img_hash and img_hash in self.duplicate_hashes:
                        self.stats['duplicates'] += 1
                        return False, "Duplicate image"
                    if img_hash:
                        self.duplicate_hashes.add(img_hash)
                
                # Lenient quality assessment
                if self.config.quality_check:
                    quality = assess_image_quality(image_path)
                    if quality < self.config.quality_threshold:
                        self.stats['low_quality'] += 1
                        return False, f"Low quality: {quality:.1f}"
                
                self.stats['valid_images'] += 1
                return True, f"Valid (quality: {quality:.1f})" if self.config.quality_check else "Valid"
                
        except Exception as e:
            self.stats['corrupted'] += 1
            return False, f"Corrupted: {str(e)}"
    
    def process_image(self, src_path, dst_path):
        """Process and save image with enhanced preprocessing"""
        try:
            with Image.open(src_path) as img:
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Enhanced preprocessing for large datasets
                if self.config.resize_images:
                    # Use high-quality resampling
                    img = img.resize(self.config.target_image_size, Image.Resampling.LANCZOS)
                
                # Optional: slight sharpening for better feature extraction
                if random.random() < 0.3:  # Apply to 30% of images
                    from PIL import ImageFilter
                    img = img.filter(ImageFilter.UnsharpMask(radius=1, percent=120, threshold=3))
                
                # Save with high quality
                img.save(dst_path, 'JPEG', quality=95, optimize=True)
                self.stats['processed_images'] += 1
                
        except Exception as e:
            logger.error(f"Failed to process {src_path}: {e}")
            self.stats['processing_errors'] += 1
            raise
    
    def analyze_dataset(self):
        """Analyze dataset - keep ALL classes"""
        logger.info("📊 Analyzing dataset for ALL classes preservation...")
        
        raw_path = Path(self.config.raw_dir)
        if not raw_path.exists():
            raise FileNotFoundError(f"Raw dataset directory not found: {self.config.raw_dir}")
        
        class_analysis = {}
        
        for class_folder in raw_path.iterdir():
            if not class_folder.is_dir():
                continue
                
            valid_images = []
            total_files = 0
            
            for img_path in class_folder.iterdir():
                total_files += 1
                if img_path.suffix.lower() in self.config.supported_extensions:
                    is_valid, reason = self.validate_image(img_path)
                    if is_valid:
                        valid_images.append(img_path)
                        
            class_analysis[class_folder.name] = {
                'total_files': total_files,
                'valid_images': len(valid_images),
                'image_paths': valid_images
            }
            
            logger.info(f"Class '{class_folder.name}': {len(valid_images)}/{total_files} valid images")
        
        return class_analysis
    
    def filter_classes_keep_all(self, class_analysis):
        """Keep ALL classes, even those with very few samples"""
        logger.info("🔍 Applying minimal filtering to keep ALL classes...")
        
        # Keep classes with at least min_images_per_class (very low threshold)
        valid_classes = {
            name: info for name, info in class_analysis.items()
            if info['valid_images'] >= self.config.min_images_per_class
        }
        
        # Report on excluded classes
        excluded_classes = set(class_analysis.keys()) - set(valid_classes.keys())
        if excluded_classes:
            logger.warning(f"Excluded {len(excluded_classes)} classes with < {self.config.min_images_per_class} images:")
            for class_name in sorted(excluded_classes):
                count = class_analysis[class_name]['valid_images']
                logger.warning(f"  - {class_name}: {count} images")
        
        logger.info(f"Keeping {len(valid_classes)}/{len(class_analysis)} classes")
        
        # Identify classes that need augmentation
        small_classes = []
        for name, info in valid_classes.items():
            if info['valid_images'] < self.config.augmentation_threshold:
                small_classes.append((name, info['valid_images']))
        
        if small_classes:
            logger.info(f"Classes needing augmentation: {len(small_classes)}")
            for name, count in small_classes:
                logger.info(f"  - {name}: {count} images (will augment to ~{self.config.target_samples_per_class})")
        
        return valid_classes
    
    def create_balanced_splits(self, valid_classes):
        """Create splits with data augmentation for small classes"""
        logger.info("✂️ Creating balanced dataset splits with augmentation...")
        
        # Reset output directory
        output_path = Path(self.config.output_dir)
        if output_path.exists():
            shutil.rmtree(output_path)
        
        # Create split directories
        for split in ["train", "val", "test"]:
            (output_path / split).mkdir(parents=True, exist_ok=True)
        
        split_stats = {"train": {}, "val": {}, "test": {}}
        
        for class_name, class_info in valid_classes.items():
            original_images = class_info['image_paths'].copy()
            total_original = len(original_images)
            
            # Shuffle images
            random.shuffle(original_images)
            
            # Determine if augmentation is needed
            needs_augmentation = total_original < self.config.augmentation_threshold
            
            if needs_augmentation and self.config.augment_small_classes:
                logger.info(f"Augmenting class '{class_name}' from {total_original} images...")
                
                # Create temporary directory for augmented images
                temp_aug_dir = output_path / "temp_augmentation" / class_name
                temp_aug_dir.mkdir(parents=True, exist_ok=True)
                
                # First, copy all original images to temp directory
                original_temp_paths = []
                for i, img_path in enumerate(original_images):
                    temp_path = temp_aug_dir / f"original_{i:03d}.jpg"
                    self.process_image(img_path, temp_path)
                    original_temp_paths.append(temp_path)
                
                # Create augmented images
                augmented_paths = []
                target_total = min(self.config.target_samples_per_class, total_original * 3)
                needed_augmentations = max(0, target_total - total_original)
                
                if needed_augmentations > 0:
                    augs_per_image = max(1, needed_augmentations // total_original)
                    
                    for i, original_path in enumerate(original_temp_paths):
                        aug_paths = create_augmented_images(
                            original_path, temp_aug_dir, f"base_{i:03d}", augs_per_image
                        )
                        augmented_paths.extend(aug_paths)
                
                # Combine original and augmented images
                all_images = original_temp_paths + augmented_paths[:needed_augmentations]
                random.shuffle(all_images)
                
                logger.info(f"  Created {len(all_images)} total images ({total_original} original + {len(all_images) - total_original} augmented)")
                
            else:
                # Use original images only
                all_images = original_images
            
            total_available = len(all_images)
            
            # Calculate split sizes (ensure each split gets at least 1 image if possible)
            if total_available >= 10:
                # Standard splits for classes with enough images
                train_size = int(total_available * self.config.train_ratio)
                val_size = int(total_available * self.config.val_ratio)
                test_size = total_available - train_size - val_size
            elif total_available >= 5:
                # Conservative splits for medium-sized classes
                train_size = max(3, int(total_available * 0.7))
                val_size = max(1, int(total_available * 0.2))
                test_size = total_available - train_size - val_size
            else:
                # Minimal splits for very small classes
                train_size = max(2, total_available - 1)
                val_size = 1 if total_available > 2 else 0
                test_size = total_available - train_size - val_size
            
            # Create splits
            train_images = all_images[:train_size]
            val_images = all_images[train_size:train_size + val_size]
            test_images = all_images[train_size + val_size:]
            
            splits = {
                "train": train_images,
                "val": val_images,
                "test": test_images
            }
            
            # Process and save images to final directories
            for split, img_list in splits.items():
                if not img_list:  # Skip empty splits
                    split_stats[split][class_name] = 0
                    continue
                
                split_class_dir = output_path / split / class_name
                split_class_dir.mkdir(parents=True, exist_ok=True)
                
                processed_count = 0
                for j, img_path in enumerate(img_list):
                    try:
                        # Generate output filename
                        if needs_augmentation and str(img_path).startswith(str(temp_aug_dir)):
                            # This is from our temp directory
                            output_name = f"{class_name}_{split}_{j:04d}.jpg"
                            output_path_full = split_class_dir / output_name
                            shutil.copy2(img_path, output_path_full)
                        else:
                            # This is an original image
                            output_name = f"{class_name}_{split}_{j:04d}.jpg"
                            output_path_full = split_class_dir / output_name
                            self.process_image(img_path, output_path_full)
                        
                        processed_count += 1
                        
                    except Exception as e:
                        logger.error(f"Failed to process {img_path}: {e}")
                
                split_stats[split][class_name] = processed_count
            
            # Clean up temporary augmentation directory
            if needs_augmentation and self.config.augment_small_classes:
                shutil.rmtree(temp_aug_dir, ignore_errors=True)
        
        # Clean up temp augmentation directory
        temp_aug_base = output_path / "temp_augmentation"
        if temp_aug_base.exists():
            shutil.rmtree(temp_aug_base, ignore_errors=True)
        
        return split_stats
    
    def generate_comprehensive_report(self, split_stats, valid_classes):
        """Generate comprehensive processing report for large dataset"""
        logger.info("📋 Generating comprehensive processing report...")
        
        # Calculate totals
        total_classes = len(valid_classes)
        total_train = sum(split_stats["train"].values())
        total_val = sum(split_stats["val"].values())
        total_test = sum(split_stats["test"].values())
        total_images = total_train + total_val + total_test
        
        # Calculate class distribution statistics
        class_sizes = []
        augmented_classes = 0
        
        for class_name in valid_classes:
            train_count = split_stats["train"].get(class_name, 0)
            val_count = split_stats["val"].get(class_name, 0)
            test_count = split_stats["test"].get(class_name, 0)
            total_count = train_count + val_count + test_count
            
            class_sizes.append(total_count)
            
            # Check if class was augmented
            original_count = valid_classes[class_name]['valid_images']
            if total_count > original_count:
                augmented_classes += 1
        
        class_sizes = np.array(class_sizes)
        
        report = {
            'processing_stats': dict(self.stats),
            'dataset_summary': {
                'total_classes': total_classes,
                'total_images': total_images,
                'train_images': total_train,
                'val_images': total_val,
                'test_images': total_test,
                'augmented_classes': augmented_classes,
                'class_distribution': {
                    'min_samples': int(class_sizes.min()),
                    'max_samples': int(class_sizes.max()),
                    'mean_samples': float(class_sizes.mean()),
                    'std_samples': float(class_sizes.std())
                }
            },
            'class_details': {}
        }
        
        # Detailed class information
        for class_name in valid_classes:
            train_count = split_stats["train"].get(class_name, 0)
            val_count = split_stats["val"].get(class_name, 0)
            test_count = split_stats["test"].get(class_name, 0)
            total_count = train_count + val_count + test_count
            original_count = valid_classes[class_name]['valid_images']
            
            report['class_details'][class_name] = {
                'train': train_count,
                'val': val_count,
                'test': test_count,
                'total': total_count,
                'original': original_count,
                'augmented': total_count > original_count
            }
        
        # Save report
        report_path = Path(self.config.output_dir) / "large_scale_dataset_report.json"
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print comprehensive summary
        print("\n" + "="*80)
        print("🎉 LARGE-SCALE DATASET PROCESSING COMPLETE!")
        print("="*80)
        print(f"📊 Processing Statistics:")
        print(f"  • Valid images processed: {self.stats['valid_images']:,}")
        print(f"  • Corrupted files: {self.stats['corrupted']}")
        print(f"  • Duplicates removed: {self.stats['duplicates']}")
        print(f"  • Low quality filtered: {self.stats['low_quality']}")
        print(f"  • Processing errors: {self.stats['processing_errors']}")
        
        print(f"\n📈 Final Large-Scale Dataset:")
        print(f"  • Total Classes: {total_classes}")
        print(f"  • Classes Augmented: {augmented_classes}")
        print(f"  • Total Images: {total_images:,}")
        print(f"  • Training: {total_train:,} ({100*total_train/total_images:.1f}%)")
        print(f"  • Validation: {total_val:,} ({100*total_val/total_images:.1f}%)")
        print(f"  • Test: {total_test:,} ({100*total_test/total_images:.1f}%)")
        
        print(f"\n📊 Class Distribution Analysis:")
        print(f"  • Smallest class: {class_sizes.min()} images")
        print(f"  • Largest class: {class_sizes.max()} images")
        print(f"  • Average per class: {class_sizes.mean():.1f} ± {class_sizes.std():.1f}")
        print(f"  • Classes with <10 images: {(class_sizes < 10).sum()}")
        print(f"  • Classes with 10-20 images: {((class_sizes >= 10) & (class_sizes < 20)).sum()}")
        print(f"  • Classes with 20+ images: {(class_sizes >= 20).sum()}")
        
        # Show sample of classes
        print(f"\n📋 Sample Class Breakdown (first 20 classes):")
        print("-" * 100)
        print(f"{'Class Name':<40} {'Train':<8} {'Val':<6} {'Test':<6} {'Total':<8} {'Original':<10} {'Aug?'}")
        print("-" * 100)
        
        class_names_sorted = sorted(report['class_details'].keys())
        for class_name in class_names_sorted[:20]:
            details = report['class_details'][class_name]
            aug_status = "Yes" if details['augmented'] else "No"
            print(f"{class_name:<40} {details['train']:<8} {details['val']:<6} "
                  f"{details['test']:<6} {details['total']:<8} {details['original']:<10} {aug_status}")
        
        if len(class_names_sorted) > 20:
            print(f"... and {len(class_names_sorted) - 20} more classes")
        
        print("-" * 100)
        print(f"💾 Detailed report saved to: {report_path}")
        
        # Recommendations for training
        print(f"\n🎯 TRAINING RECOMMENDATIONS FOR {total_classes} CLASSES:")
        print("=" * 80)
        
        if total_classes >= 100:
            print("🔥 ULTRA-LARGE SCALE (100+ classes):")
            print("  • Use EfficientNet-B2 or B3 architecture")
            print("  • Set batch_size=12-16, epochs=40-60")
            print("  • Use learning_rate=0.0003-0.0005")
            print("  • Set dropout_rate=0.3-0.4")
            print("  • Expected accuracy: 50-70% (excellent for 100+ classes)")
            print("  • Use curriculum learning or hierarchical classification")
        elif total_classes >= 80:
            print("🚀 LARGE SCALE (80+ classes):")
            print("  • Use EfficientNet-B2 architecture")
            print("  • Set batch_size=16-20, epochs=35-50")
            print("  • Use learning_rate=0.0005")
            print("  • Set dropout_rate=0.3")
            print("  • Expected accuracy: 60-75%")
        else:
            print("📊 MEDIUM SCALE:")
            print("  • Use EfficientNet-B0 or B2")
            print("  • Standard training parameters should work well")
        
        print(f"\n⚖️ DATASET BALANCE ASSESSMENT:")
        balance_ratio = class_sizes.std() / class_sizes.mean()
        if balance_ratio < 0.5:
            print("✅ Well-balanced dataset")
        elif balance_ratio < 1.0:
            print("⚠️ Moderately imbalanced - use class weighting")
        else:
            print("🔴 Highly imbalanced - use strong class weighting and focal loss")
        
        return report


def main():
    parser = argparse.ArgumentParser(description='Large-Scale Fish Dataset Preprocessing - Keep All Classes')
    parser.add_argument('--raw_dir', type=str, default='app/datasets/raw_fish_images',
                       help='Raw dataset directory')
    parser.add_argument('--output_dir', type=str, default='app/datasets/fish_images',
                       help='Output directory for processed dataset')
    parser.add_argument('--min_images_per_class', type=int, default=3,
                       help='Minimum images per class (very low to keep all classes)')
    parser.add_argument('--no_augmentation', action='store_true',
                       help='Skip augmentation of small classes')
    parser.add_argument('--augmentation_threshold', type=int, default=10,
                       help='Classes with fewer images get augmented')
    parser.add_argument('--target_samples_per_class', type=int, default=15,
                       help='Target number of images per class after augmentation')
    parser.add_argument('--no_quality_check', action='store_true',
                       help='Skip image quality assessment')
    parser.add_argument('--seed', type=int, default=42,
                       help='Random seed for reproducible splits')
    parser.add_argument('--image_size', type=int, default=288,
                       help='Target image size for processing')
    
    args = parser.parse_args()
    
    # Set random seed
    random.seed(args.seed)
    np.random.seed(args.seed)
    
    # Create configuration
    config = LargeScaleDatasetConfig()
    config.raw_dir = args.raw_dir
    config.output_dir = args.output_dir
    config.min_images_per_class = args.min_images_per_class
    config.augment_small_classes = not args.no_augmentation
    config.augmentation_threshold = args.augmentation_threshold
    config.target_samples_per_class = args.target_samples_per_class
    config.quality_check = not args.no_quality_check
    config.target_image_size = (args.image_size, args.image_size)
    
    logger.info("🐟 LARGE-SCALE FISH DATASET PREPROCESSING")
    logger.info("🎯 Goal: Keep ALL classes while ensuring trainability")
    logger.info(f"📊 Min images per class: {config.min_images_per_class}")
    logger.info(f"🔄 Augment classes with < {config.augmentation_threshold} images: {'Yes' if config.augment_small_classes else 'No'}")
    
    try:
        processor = LargeScaleDatasetProcessor(config)
        
        # Step 1: Analyze raw dataset
        logger.info("\n" + "="*60)
        logger.info("STEP 1: ANALYZING RAW DATASET")
        logger.info("="*60)
        class_analysis = processor.analyze_dataset()
        
        # Step 2: Apply minimal filtering to keep all classes
        logger.info("\n" + "="*60)
        logger.info("STEP 2: APPLYING MINIMAL FILTERING")
        logger.info("="*60)
        valid_classes = processor.filter_classes_keep_all(class_analysis)
        
        if not valid_classes:
            logger.error("❌ No valid classes found after filtering!")
            return
        
        logger.info(f"✅ Proceeding with {len(valid_classes)} classes")
        
        # Step 3: Create balanced splits with augmentation
        logger.info("\n" + "="*60)
        logger.info("STEP 3: CREATING BALANCED SPLITS")
        logger.info("="*60)
        split_stats = processor.create_balanced_splits(valid_classes)
        
        # Step 4: Generate comprehensive report
        logger.info("\n" + "="*60)
        logger.info("STEP 4: GENERATING REPORT")
        logger.info("="*60)
        report = processor.generate_comprehensive_report(split_stats, valid_classes)
        
        logger.info("✅ Large-scale dataset preprocessing completed successfully!")
        logger.info(f"🎉 Ready to train with {len(valid_classes)} classes!")
        
    except Exception as e:
        logger.error(f"❌ Large-scale dataset preprocessing failed: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise


if __name__ == "__main__":
    main()