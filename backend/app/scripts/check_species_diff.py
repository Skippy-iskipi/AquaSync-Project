import os
import sys
from sqlalchemy import text
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

from backend.app.database import get_db

def check_species_differences():
    """Find differences between fish_species and fish_images tables"""
    db = next(get_db())
    try:
        # Get all species from fish_species table
        species_query = text("SELECT common_name FROM fish_species ORDER BY common_name")
        species_result = db.execute(species_query).fetchall()
        species_names = set(row[0].lower() for row in species_result)

        # Get all species from fish_images table
        images_query = text("SELECT DISTINCT fish_species FROM fish_images ORDER BY fish_species")
        images_result = db.execute(images_query).fetchall()
        image_species = set(row[0].lower() for row in images_result)

        # Find differences
        only_in_species = species_names - image_species
        only_in_images = image_species - species_names

        print("\nSpecies only in fish_species table:")
        for name in sorted(only_in_species):
            print(f"- {name}")

        print("\nSpecies only in fish_images table:")
        for name in sorted(only_in_images):
            print(f"- {name}")

        # Print exact counts
        print(f"\nTotal in fish_species: {len(species_names)}")
        print(f"Total in fish_images: {len(image_species)}")
        print(f"Common between both tables: {len(species_names & image_species)}")

    except Exception as e:
        print(f"Error checking species differences: {str(e)}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    check_species_differences() 