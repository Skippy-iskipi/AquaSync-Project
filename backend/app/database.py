import os
from dotenv import load_dotenv
from supabase import create_client, Client
import logging
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# --- SQLAlchemy Setup ---
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")
if not SQLALCHEMY_DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable not set. Please add it to your .env file.")

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
# -------------------------

# Initialize Supabase client
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

def get_db():
    """FastAPI dependency to get a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def verify_db_schema():
    """Verify that the database schema is correct"""
    try:
        # Check if fish_species table exists and has required columns
        response = supabase.table('fish_species').select('*').limit(1).execute()
        if response.data:
            logger.info("Database schema verified successfully")
            return True
        else:
            logger.error("Database schema verification failed: fish_species table is empty")
            return False
    except Exception as e:
        logger.error(f"Error verifying database schema: {e}")
        return False

def get_fish_df():
    """Get fish data as a pandas DataFrame"""
    try:
        response = supabase.table('fish_species').select('*').execute()
        if response.data:
            return pd.DataFrame(response.data)
        return None
    except Exception as e:
        logger.error(f"Error getting fish data: {e}")
        return None

def print_columns():
    """Print all column names from the fish_species table"""
    try:
        df = get_fish_df()
        logger.info(f"Database columns: {df.columns.tolist()}")
    except Exception as e:
        logger.error(f"Error getting columns: {str(e)}") 