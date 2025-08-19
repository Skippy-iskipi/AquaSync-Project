import os
from supabase import create_client

# --- Supabase connection ---
SUPABASE_URL = "https://rdiwfttfxxpenrcxyfuv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkaXdmdHRmeHhwZW5yY3h5ZnV2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDE0NjM1MywiZXhwIjoyMDY1NzIyMzUzfQ.s3bFGhsUl9YR5AEE355mCe_kFokgl0lQxM_vir9QIfU"  # Use service key for full read
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Path to your raw images folder
RAW_IMAGES_FOLDER = os.path.join(
    os.path.dirname(__file__),  # current script folder
    "datasets",
    "raw_fish_images"
)

def find_species_without_images():
    # 1. Get all fish species names from the database
    species_resp = supabase.table("fish_species").select("common_name").execute()
    species_names = {row["common_name"].strip().lower() for row in species_resp.data if row.get("common_name")}

    # 2. Get all folder names in raw_fish_images
    local_names = {
        folder_name.strip().lower()
        for folder_name in os.listdir(RAW_IMAGES_FOLDER)
        if os.path.isdir(os.path.join(RAW_IMAGES_FOLDER, folder_name))
    }

    # 3. Find names in DB but not in local folders
    unmatched = sorted(species_names - local_names)

    print(f"Found {len(unmatched)} fish in fish_species table with no folder in raw_fish_images:")
    for name in unmatched:
        print("-", name)

if __name__ == "__main__":
    find_species_without_images()
