"""
Initialize the database tables and create initial data for the fish_images table.
Run this script to set up the database structure for the fish images API.
"""

from app.database import engine, get_db
from app.models.image_dataset import Base, FishImage, DatasetType
from sqlalchemy.orm import Session
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def init_db():
    """Create database tables if they don't exist."""
    logger.info("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created successfully.")

def create_sample_data():
    """Create sample data in the fish_images table."""
    db = next(get_db())
    try:
        # Check if we already have data
        count = db.query(FishImage).count()
        if count > 0:
            logger.info(f"Database already contains {count} fish images. Skipping sample data creation.")
            return
        
        logger.info("Creating sample fish image records...")
        
        # Create empty placeholder records for testing
        # In a real scenario, you would load actual images
        sample_species = ["Tilapia", "Bangus", "Goldfish", "Guppy", "Betta"]
        dataset_types = [DatasetType.TRAIN, DatasetType.TEST, DatasetType.VALIDATION]
        
        # Create 15 sample records (3 for each species)
        for species in sample_species:
            for i, dt in enumerate(dataset_types):
                fish_image = FishImage(
                    fish_species=species,
                    image_name=f"{species.lower()}_{dt.value}_{i+1}.jpg",
                    # Empty binary data for placeholder
                    image_data=b'',
                    dataset_type=dt
                )
                db.add(fish_image)
        
        db.commit()
        logger.info("Sample fish image records created successfully.")
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating sample data: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    init_db()
    create_sample_data()
