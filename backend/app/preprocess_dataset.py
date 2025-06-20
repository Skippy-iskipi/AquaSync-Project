import os
import shutil
import random
from pathlib import Path
from PIL import Image

# Configuration
RAW_DIR = "app/datasets/raw_fish_images"
OUTPUT_DIR = "app/datasets/fish_images"
IMAGE_SIZE = (300, 300)  # EfficientNet-B3 recommended size

# Split ratios
TRAIN_RATIO = 0.7
VAL_RATIO = 0.15
TEST_RATIO = 0.15

# Reset output folders
for split in ["train", "val", "test"]:
    split_dir = Path(OUTPUT_DIR) / split
    if split_dir.exists():
        shutil.rmtree(split_dir)
    split_dir.mkdir(parents=True)

# Supported extensions
EXTENSIONS = [".jpg", ".jpeg", ".png"]

# Process each class folder
for class_folder in Path(RAW_DIR).iterdir():
    if not class_folder.is_dir():
        continue

    # Collect image paths
    images = [img for img in class_folder.iterdir() if img.suffix.lower() in EXTENSIONS]
    if len(images) < 10:
        print(f"⚠️ Skipping '{class_folder.name}' (only {len(images)} images)")
        continue

    random.shuffle(images)
    total = len(images)
    train_cut = int(total * TRAIN_RATIO)
    val_cut = int(total * (TRAIN_RATIO + VAL_RATIO))

    splits = {
        "train": images[:train_cut],
        "val": images[train_cut:val_cut],
        "test": images[val_cut:]
    }

    for split, img_list in splits.items():
        split_class_dir = Path(OUTPUT_DIR) / split / class_folder.name
        split_class_dir.mkdir(parents=True, exist_ok=True)

        for img_path in img_list:
            try:
                img = Image.open(img_path).convert("RGB")
                img = img.resize(IMAGE_SIZE)
                img.save(split_class_dir / img_path.name)
            except Exception as e:
                print(f"❌ Failed to process {img_path}: {e}")

print("\n✅ Dataset successfully split into train/val/test with resized images.")
