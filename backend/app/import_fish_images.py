import os
import logging
from pathlib import Path
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine
from app.models.image_dataset import FishImage, DatasetType, Base

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

def import_images(dataset_dir: str, dataset_type: DatasetType):
    """
    Import fish images from a directory into the database
    
    Args:
        dataset_dir: Path to the directory containing fish species folders
        dataset_type: Type of dataset (train, test, or validation)
    """
    db = SessionLocal()
    try:
        dataset_path = Path(dataset_dir)
        if not dataset_path.exists():
            logger.error(f"Directory not found: {dataset_dir}")
            return
        
        # Get all species directories
        species_dirs = [d for d in dataset_path.iterdir() if d.is_dir()]
        total_images = 0
        
        for species_dir in species_dirs:
            species_name = species_dir.name
            logger.info(f"Processing {species_name}...")
            
            # Get all image files
            image_files = [f for f in species_dir.glob("*.jpg") or species_dir.glob("*.png") or species_dir.glob("*.jpeg")]
            
            for img_file in image_files:
                # Read image binary data
                with open(img_file, "rb") as f:
                    image_data = f.read()
                
                # Create database record
                fish_image = FishImage(
                    fish_species=species_name,
                    image_name=img_file.name,
                    image_data=image_data,
                    dataset_type=dataset_type
                )
                
                db.add(fish_image)
                total_images += 1
                
                # Commit in batches to avoid memory issues
                if total_images % 100 == 0:
                    db.commit()
                    logger.info(f"Imported {total_images} images so far...")
            
        # Final commit
        db.commit()
        logger.info(f"Successfully imported {total_images} images from {dataset_type.value} dataset")
    
    except Exception as e:
        db.rollback()
        logger.error(f"Error importing images: {str(e)}")
    finally:
        db.close()

def main():
    """Import all fish images from train, test, and validation sets"""
    base_dir = Path(__file__).parent / "datasets" / "fish_images"
    
    # Import training images
    import_images(str(base_dir / "train"), DatasetType.TRAIN)
    
    # Import validation images
    import_images(str(base_dir / "val"), DatasetType.VALIDATION)
    
    # Import test images
    import_images(str(base_dir / "test"), DatasetType.TEST)
    
    logger.info("Image import complete!")

if __name__ == "__main__":
    main()
