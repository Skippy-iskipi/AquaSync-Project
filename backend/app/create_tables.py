from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import os
from dotenv import load_dotenv
from supabase import create_client, Client

# Load environment variables
load_dotenv()

# Initialize Supabase client
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

Base = declarative_base()

class FishSpecies(Base):
    __tablename__ = "fish_species"
    
    id = Column(Integer, primary_key=True)
    common_name = Column(String, unique=True, nullable=False)
    scientific_name = Column(String)
    water_type = Column(String)
    max_size = Column(Float)
    temperament = Column(String)
    temperature_range = Column(String)
    ph_range = Column(String)
    habitat_type = Column(String)
    social_behavior = Column(String)
    tank_level = Column(String)
    minimum_tank_size = Column(Integer)
    compatibility_notes = Column(String)
    diet = Column(String)
    lifespan = Column(String)
    care_level = Column(String)
    preferred_food = Column(String)
    feeding_frequency = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

def init_db():
    """Initialize the database tables"""
    try:
        # Verify Supabase connection
        response = supabase.table('fish_species').select('count').execute()
        print("Successfully connected to Supabase")
    except Exception as e:
        print(f"Error connecting to Supabase: {e}")
        raise

if __name__ == "__main__":
    init_db() 