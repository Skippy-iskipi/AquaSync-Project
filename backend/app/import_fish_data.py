import pandas as pd
import psycopg2
from sqlalchemy import create_engine
import os
import re

# Database connection parameters
DATABASE_URL = "postgresql://postgres:aquasync@localhost:5432/aquasync"

def create_fish_species_table(conn):
    """Create the fish_species table if it doesn't exist"""
    cursor = conn.cursor()
    
    create_table_query = """
    CREATE TABLE IF NOT EXISTS fish_species (
        id SERIAL PRIMARY KEY,
        common_name VARCHAR(255) UNIQUE,
        scientific_name VARCHAR(255),
        max_size FLOAT,
        temperament VARCHAR(50),
        water_type VARCHAR(50),
        temperature_range VARCHAR(50),
        ph_range VARCHAR(50),
        habitat_type VARCHAR(255),
        social_behavior VARCHAR(255),
        tank_level VARCHAR(50),
        minimum_tank_size FLOAT,
        compatibility_notes TEXT,
        diet VARCHAR(50),
        lifespan VARCHAR(50),
        care_level VARCHAR(50),
        preferred_food TEXT,
        feeding_frequency VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """
    
    cursor.execute(create_table_query)
    conn.commit()
    cursor.close()

# --- UPSERT LOGIC for fish_species table ---
def upsert_fish_species_from_csv(csv_path):
    """
    Import fish species from CSV and upsert them to the database.
    For each row, if a fish with the same common_name exists, update it.
    Otherwise, insert a new row.
    
    Args:
        csv_path: Path to the CSV file
        
    Returns:
        dict: Result with count of updated and inserted rows
    """
    print(f"Starting upsert from CSV: {csv_path}")
    
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        raise FileNotFoundError(f"CSV file not found at {csv_path}")
    
    try:
        # Read CSV file with more robust error handling
        try:
            # First try with default settings
            df = pd.read_csv(csv_path)
        except Exception as csv_error:
            print(f"Initial CSV parsing failed: {str(csv_error)}")
            try:
                # Try with more flexible parsing options
                df = pd.read_csv(
                    csv_path, 
                    on_bad_lines='skip',  # Skip bad lines (pandas 1.3+)
                    quoting=pd.io.common.csv.QUOTE_NONE,  # Disable quoting
                    escapechar='\\'         # Use backslash as escape character
                )
                print(f"CSV had errors but was partially parsed with {len(df)} rows")
            except Exception as flexible_error:
                print(f"Flexible CSV parsing failed: {str(flexible_error)}")
                # If that fails too, try with even more permissive settings
                with open(csv_path, 'r', encoding='utf-8', errors='replace') as f:
                    csv_content = f.read()
                
                # Try to fix common CSV issues
                fixed_content = csv_content.replace('\\"', '"')  # Fix escaped quotes
                fixed_content = fixed_content.replace('\r', '')  # Remove carriage returns
                
                # Try to fix the specific error in the screenshot
                fixed_content = re.sub(r'([^,]+),([^,]+),([^,]+)', r'\1,"\2",\3', fixed_content)
                
                # Write fixed content to a temporary file
                fixed_path = csv_path + '.fixed'
                with open(fixed_path, 'w', encoding='utf-8') as f:
                    f.write(fixed_content)
                
                try:
                    # Try to read the fixed file
                    df = pd.read_csv(fixed_path, encoding='utf-8', on_bad_lines='skip')
                    print(f"CSV was fixed and parsed with {len(df)} rows")
                    os.remove(fixed_path)  # Clean up
                except Exception as last_error:
                    print(f"Last resort CSV parsing failed: {str(last_error)}")
                    # If all else fails, try to manually parse the CSV
                    try:
                        # Manual CSV parsing as a last resort
                        rows = []
                        with open(csv_path, 'r', encoding='utf-8', errors='replace') as f:
                            lines = f.readlines()
                        
                        # Get headers from first line
                        headers = lines[0].strip().split(',')
                        headers = [h.lower().replace(' ', '_') for h in headers]
                        
                        # Process each line
                        for i, line in enumerate(lines[1:], 1):
                            try:
                                values = line.strip().split(',')
                                if len(values) >= len(headers):
                                    row = {headers[j]: values[j] for j in range(len(headers))}
                                    rows.append(row)
                            except Exception as e:
                                print(f"Skipping line {i}: {str(e)}")
                        
                        df = pd.DataFrame(rows)
                        print(f"Manually parsed CSV with {len(df)} rows")
                    except Exception as manual_error:
                        print(f"Manual CSV parsing failed: {str(manual_error)}")
                        os.remove(fixed_path)  # Clean up
                        raise csv_error
        
        print(f"Read CSV with {len(df)} rows and columns: {df.columns.tolist()}")
        
        # Clean column names (convert to snake_case)
        df.columns = [col.lower().replace(' ', '_') for col in df.columns]
        
        # Connect to database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # Create the table if it doesn't exist
        create_fish_species_table(conn)
        
        # Get existing columns in the fish_species table
        cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'fish_species'")
        db_columns = [row[0] for row in cursor.fetchall()]
        print(f"Database columns: {db_columns}")
        
        # Create a mapping between CSV columns and DB columns
        column_mapping = {
            'max_size_(cm)': 'max_size',
            'temperature_range_(°c)': 'temperature_range',
            'minimum_tank_size_(l)': 'minimum_tank_size',
            # Add any other mappings needed
        }
        
        # Process each row in the CSV
        updated = 0
        inserted = 0
        
        for _, row in df.iterrows():
            # Convert row to dict and drop NaN values
            row_dict = row.dropna().to_dict()
            
            # Skip rows without common_name
            if 'common_name' not in row_dict or not row_dict['common_name']:
                continue
            
            # Map CSV column names to DB column names
            mapped_row = {}
            for k, v in row_dict.items():
                if k in column_mapping and column_mapping[k] in db_columns:
                    mapped_row[column_mapping[k]] = v
                elif k in db_columns:
                    mapped_row[k] = v
            
            # Only keep columns that exist in the database
            valid_row = mapped_row
            
            if not valid_row:
                print(f"Warning: No valid columns for row with common_name {row_dict.get('common_name')}")
                continue
                
            # Check if this fish already exists
            common_name = row_dict['common_name']
            cursor.execute("SELECT COUNT(*) FROM fish_species WHERE common_name = %s", (common_name,))
            exists = cursor.fetchone()[0] > 0
            
            if exists:
                # Update existing fish
                set_clause = ", ".join([f'"{col}" = %s' for col in valid_row.keys() if col != 'common_name'])
                if set_clause:  # Only update if there are columns to update
                    values = [valid_row[col] for col in valid_row.keys() if col != 'common_name']
                    values.append(common_name)  # For the WHERE clause
                    
                    update_query = f'UPDATE fish_species SET {set_clause} WHERE common_name = %s'
                    cursor.execute(update_query, values)
                    updated += 1
            else:
                # Insert new fish
                columns = list(valid_row.keys())
                placeholders = ", ".join(["%s"] * len(columns))
                values = [valid_row[col] for col in columns]
                
                # QUOTE all column names for PostgreSQL (build outside the f-string)
                quoted_columns = ', '.join([f'"{col}"' for col in columns])
                insert_query = f'INSERT INTO fish_species ({quoted_columns}) VALUES ({placeholders})'
                cursor.execute(insert_query, values)
                inserted += 1
        
        # Commit changes
        conn.commit()
        cursor.close()
        conn.close()
        
        result = {
            "updated": updated,
            "inserted": inserted,
            "total": updated + inserted
        }
        print(f"Upsert completed: {result}")
        return result
        
    except Exception as e:
        print(f"Error in upsert_fish_species_from_csv: {str(e)}")
        import traceback
        traceback.print_exc()
        raise

# --- Export fish species to CSV for ML ---
def export_fish_species_to_csv(output_path=None):
    """
    Export fish species from database to a clean CSV file for ML training.
    Only exports relevant columns, excluding internal DB columns.
    
    Args:
        output_path: Path where to save the CSV file. If None, uses a default path.
    
    Returns:
        Path to the exported CSV file
    """
    if output_path is None:
        # Use an absolute path to ensure it works in all contexts
        output_path = os.path.abspath("app/datasets/csv/fish_species_for_ml.csv")
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    try:
        # Connect to database
        conn = psycopg2.connect(DATABASE_URL)
        
        # Define the columns we want to export (exclude internal DB columns)
        ml_columns = [
            'common_name', 'scientific_name', 'max_size', 'temperament', 
            'water_type', 'temperature_range', 'ph_range', 'habitat_type', 
            'social_behavior', 'tank_level', 'minimum_tank_size', 
            'compatibility_notes', 'diet', 'lifespan', 'care_level', 
            'preferred_food', 'feeding_frequency'
        ]
        
        # Check which columns actually exist in the table
        cursor = conn.cursor()
        cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'fish_species'")
        existing_columns = [row[0] for row in cursor.fetchall()]
        
        # Only use columns that actually exist in the table
        valid_columns = [col for col in ml_columns if col in existing_columns]
        
        if not valid_columns:
            print("No valid columns found in fish_species table")
            return None
        
        # Create SQL query to select only the columns we want
        columns_sql = ', '.join(valid_columns)
        query = f"SELECT {columns_sql} FROM fish_species"
        
        # Read data into DataFrame
        df = pd.read_sql(query, conn)
        
        # Export to CSV
        df.to_csv(output_path, index=False)
        
        print(f"Exported {len(df)} fish species to {output_path}")
        conn.close()
        
        return output_path
    
    except Exception as e:
        print(f"Error exporting fish species to CSV: {str(e)}")
        raise

if __name__ == "__main__":
    upsert_fish_species_from_csv("app/datasets/csv/fish_species_dataset.csv")