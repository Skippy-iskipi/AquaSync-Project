#!/usr/bin/env python3
"""
Analyze class distribution in the fish image dataset.
This script helps identify class imbalance issues that could affect model training.
"""

import os
import sys
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from collections import Counter

def analyze_dataset(data_dir):
    """Analyze the class distribution in the dataset"""
    print(f"Analyzing dataset in {data_dir}...")
    
    # Check if data directory exists
    if not os.path.exists(data_dir):
        print(f"Error: Directory {data_dir} does not exist")
        return
    
    # Check for train directory
    train_dir = os.path.join(data_dir, 'train')
    if not os.path.exists(train_dir):
        print(f"Error: Training directory {train_dir} does not exist")
        return
    
    # Get all class directories
    class_dirs = [d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))]
    
    if not class_dirs:
        print("Error: No class directories found in the training set")
        return
    
    print(f"Found {len(class_dirs)} classes")
    
    # Count images in each class
    class_counts = {}
    
    for class_name in class_dirs:
        class_path = os.path.join(train_dir, class_name)
        image_files = [f for f in os.listdir(class_path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        class_counts[class_name] = len(image_files)
    
    # Create dataframe for analysis
    df = pd.DataFrame({
        'class': list(class_counts.keys()),
        'count': list(class_counts.values())
    })
    
    df = df.sort_values('count', ascending=False)
    
    # Compute statistics
    total_images = df['count'].sum()
    avg_images = df['count'].mean()
    median_images = df['count'].median()
    min_images = df['count'].min()
    max_images = df['count'].max()
    std_dev = df['count'].std()
    
    # Print statistics
    print("\n=== Dataset Statistics ===")
    print(f"Total classes: {len(class_dirs)}")
    print(f"Total images: {total_images}")
    print(f"Average images per class: {avg_images:.2f}")
    print(f"Median images per class: {median_images}")
    print(f"Minimum images in a class: {min_images} (Class: {df.iloc[-1]['class']})")
    print(f"Maximum images in a class: {max_images} (Class: {df.iloc[0]['class']})")
    print(f"Standard deviation: {std_dev:.2f}")
    
    # Calculate imbalance metrics
    imbalance_ratio = max_images / min_images if min_images > 0 else float('inf')
    print(f"Imbalance ratio (max/min): {imbalance_ratio:.2f}")
    
    # Print top and bottom 10 classes
    print("\n=== Top 10 Classes (Most Images) ===")
    for i, row in df.head(10).iterrows():
        print(f"{row['class']}: {row['count']} images")
    
    print("\n=== Bottom 10 Classes (Least Images) ===")
    for i, row in df.tail(10).iterrows():
        print(f"{row['class']}: {row['count']} images")
    
    # Check for validation set
    val_dir = os.path.join(data_dir, 'val')
    if os.path.exists(val_dir):
        val_class_dirs = [d for d in os.listdir(val_dir) if os.path.isdir(os.path.join(val_dir, d))]
        
        # Check if all classes in training set have corresponding validation data
        missing_val = set(class_dirs) - set(val_class_dirs)
        if missing_val:
            print(f"\nWARNING: {len(missing_val)} classes have no validation data:")
            for cls in sorted(missing_val):
                print(f"  - {cls}")
    else:
        print("\nWARNING: No validation directory found")
    
    # Analyze class imbalance and output recommendations
    if imbalance_ratio > 10:
        print("\n=== Class Imbalance Analysis ===")
        print(f"WARNING: Severe class imbalance detected (ratio {imbalance_ratio:.2f})")
        print("Recommendations:")
        print("1. Use weighted sampling or class weights during training")
        print("2. Augment classes with fewer samples")
        print("3. Consider collecting more data for underrepresented classes")
        print("4. Consider using balanced accuracy or F1 score instead of accuracy")
    
    # Create and save visualization
    plt.figure(figsize=(12, 8))
    colors = plt.cm.viridis(np.linspace(0, 1, len(df)))
    
    bars = plt.barh(df['class'], df['count'], color=colors)
    plt.xlabel('Number of Images')
    plt.ylabel('Fish Classes')
    plt.title('Number of Training Images per Fish Class')
    plt.tight_layout()
    
    # Save the figure
    output_dir = os.path.join(os.path.dirname(data_dir), 'analysis')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, 'class_distribution.png')
    plt.savefig(output_path, dpi=300)
    print(f"\nClass distribution visualization saved to {output_path}")
    
    # Create a histogram of class sizes
    plt.figure(figsize=(10, 6))
    plt.hist(df['count'], bins=20, color='skyblue', edgecolor='black')
    plt.xlabel('Number of Images in Class')
    plt.ylabel('Number of Classes')
    plt.title('Distribution of Class Sizes')
    plt.grid(True, linestyle='--', alpha=0.7)
    
    # Save the histogram
    histogram_path = os.path.join(output_dir, 'class_size_histogram.png')
    plt.savefig(histogram_path, dpi=300)
    print(f"Class size histogram saved to {histogram_path}")
    
    # Save the data to CSV
    csv_path = os.path.join(output_dir, 'class_distribution.csv')
    df.to_csv(csv_path, index=False)
    print(f"Class distribution data saved to {csv_path}")
    
    # Show the plots if not in a headless environment
    if os.environ.get('DISPLAY'):
        plt.show()

def main():
    parser = argparse.ArgumentParser(description='Analyze fish dataset class distribution')
    parser.add_argument('--data-dir', 
                        default='app/datasets/fish_images',
                        help='Directory containing the fish image dataset')
    
    args = parser.parse_args()
    analyze_dataset(args.data_dir)

if __name__ == '__main__':
    main() 