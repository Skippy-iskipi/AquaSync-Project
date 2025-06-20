from sqlalchemy import create_engine, text
import pandas as pd
from sklearn.preprocessing import LabelEncoder
import joblib

# Database connection
engine = create_engine('postgresql://postgres:aquasync@localhost:5432/aquasync')

# Update water type in database
with engine.connect() as conn:
    conn.execute(text("UPDATE fish_species SET water_type = 'Saltwater' WHERE water_type = 'Marine'"))
    conn.commit()
print("✅ Updated water type from 'Marine' to 'Saltwater' in database")

# Load fish data
fish_df = pd.read_sql('SELECT * FROM fish_species', engine)

# Create and fit new label encoders
le_water = LabelEncoder()
le_temperament = LabelEncoder()
le_diet = LabelEncoder()

# Fit the encoders with the updated data
fish_df["water_type"] = le_water.fit_transform(fish_df["water_type"])
fish_df["temperament"] = le_temperament.fit_transform(fish_df["temperament"])
fish_df["diet"] = le_diet.fit_transform(fish_df["diet"])

# Save the updated encoders
joblib.dump(le_water, 'app/trained_models/encoder_water_type.pkl')
joblib.dump(le_temperament, 'app/trained_models/encoder_temperament.pkl')
joblib.dump(le_diet, 'app/trained_models/encoder_diet.pkl')

print("✅ Updated and saved new label encoders")
print("✅ Done! You can now restart your FastAPI server") 