import os
import sys
from sqlalchemy import text
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

from backend.app.database import get_db

def fix_glass_fish():
    """Fix the glass_fish naming issue by updating it to glass_catfish"""
    db = next(get_db())
    try:
        # Update fish_images table to change glass_fish to glass_catfish
        update_query = text("""
            UPDATE fish_images 
            SET fish_species = 'glass_catfish' 
            WHERE fish_species = 'glass_fish'
        """)
        result = db.execute(update_query)
        db.commit()
        
        print(f"Updated {result.rowcount} images from glass_fish to glass_catfish")
        
    except Exception as e:
        db.rollback()
        print(f"Error fixing glass_fish: {str(e)}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    fix_glass_fish() 