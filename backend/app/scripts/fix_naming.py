from sqlalchemy import text
from ..database import get_db

def standardize_name(name):
    """Convert a name to standardized format (lowercase with underscores)"""
    return name.strip().replace(" ", "_").lower()

def fix_naming_consistency():
    """Fix naming consistency between fish_species and fish_images tables"""
    db = next(get_db())
    try:
        # Get all species from fish_species table
        species_query = text("SELECT common_name FROM fish_species")
        species_result = db.execute(species_query).fetchall()
        species_names = [row[0] for row in species_result]

        # Get all species from fish_images table
        images_query = text("SELECT DISTINCT fish_species FROM fish_images")
        images_result = db.execute(images_query).fetchall()
        image_species = [row[0] for row in images_result]

        print("Starting naming consistency fix...")
        print(f"Found {len(species_names)} species in fish_species table")
        print(f"Found {len(image_species)} unique species in fish_images table")

        # Update fish_species table
        for name in species_names:
            standardized = standardize_name(name)
            update_query = text("""
                UPDATE fish_species 
                SET common_name = :standardized 
                WHERE common_name = :original
            """)
            db.execute(update_query, {"standardized": standardized, "original": name})
            print(f"Updated fish_species: {name} -> {standardized}")

        # Update fish_images table
        for name in image_species:
            standardized = standardize_name(name)
            update_query = text("""
                UPDATE fish_images 
                SET fish_species = :standardized 
                WHERE fish_species = :original
            """)
            db.execute(update_query, {"standardized": standardized, "original": name})
            print(f"Updated fish_images: {name} -> {standardized}")

        db.commit()
        print("Successfully updated all names to consistent format")

    except Exception as e:
        db.rollback()
        print(f"Error fixing naming consistency: {str(e)}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    fix_naming_consistency() 