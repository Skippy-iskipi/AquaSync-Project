from supabase import create_client, Client
import os
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Get Supabase credentials from environment variables
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")  # Use the service role key

if not SUPABASE_URL or not SUPABASE_KEY:
    raise ValueError("Missing Supabase credentials. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.")

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def get_supabase_client() -> Client:
    """Get Supabase client instance"""
    return supabase

def verify_supabase_connection():
    """Verify that the Supabase connection is working"""
    try:
        # Test the connection by querying the fish_species table
        response = supabase.table('fish_species').select('count').execute()
        logger.info("Successfully connected to Supabase")
        return True
    except Exception as e:
        logger.error(f"Supabase connection failed: {str(e)}")
        raise