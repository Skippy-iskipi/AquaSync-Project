from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
import pandas as pd
import joblib

app = FastAPI()

# Load cleaned fish dataset and trained model
fish_df = pd.read_csv("app/datasets/aquarium_fish_dataset_cleaned_final.csv")
model = joblib.load("app/trained_models/random_forest_model_with_diet.pkl")

# Encoding maps
TEMPERAMENT = {"Peaceful": 1, "Semi-aggressive": 2, "Aggressive": 3}
DIET = {"Herbivore": 1, "Algaevore": 2, "Omnivore": 3, "Carnivore": 4}

class FishGroup(BaseModel):
    fish_names: List[str]

# Compatibility reason logic
def get_reason(a, b):
    if a["Water Type"] != b["Water Type"]:
        return "Water type mismatch"
    if TEMPERAMENT.get(a["Temperament"], 2) == 3 or TEMPERAMENT.get(b["Temperament"], 2) == 3:
        return "Aggressive temperament conflict"
    if abs(a["Max Size (cm)"] - b["Max Size (cm)"]) > 8:
        return "Large size difference"
    if 4 in {DIET.get(a["Diet"], 3), DIET.get(b["Diet"], 3)} and 1 in {DIET.get(a["Diet"], 3), DIET.get(b["Diet"], 3)}:
        return "Carnivore-herbivore conflict"
    return "General incompatibility"

# Build feature input for a pair
def build_feature(fish_a, fish_b):
    row = {
        "Max Size A": fish_a["Max Size (cm)"],
        "Max Size B": fish_b["Max Size (cm)"],
        "Temperament A Encoded": TEMPERAMENT.get(fish_a["Temperament"], 2),
        "Temperament B Encoded": TEMPERAMENT.get(fish_b["Temperament"], 2),
        "Water Type A": fish_a["Water Type"],
        "Water Type B": fish_b["Water Type"],
        "Diet A Encoded": DIET.get(fish_a["Diet"], 3),
        "Diet B Encoded": DIET.get(fish_b["Diet"], 3),
    }
    feature = pd.get_dummies(pd.DataFrame([row]))
    feature = feature.reindex(columns=model.feature_names_in_, fill_value=0)
    return feature

@app.post("/check-group")
def check_group_compatibility(payload: FishGroup):
    names = payload.fish_names
    missing = [name for name in names if name not in fish_df["Common Name"].values]
    if missing:
        raise HTTPException(status_code=404, detail=f"Fish not found: {missing}")

    incompatible = []
    compatible_pairs = []

    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            name_a, name_b = names[i], names[j]
            fish_a = fish_df[fish_df["Common Name"] == name_a].iloc[0]
            fish_b = fish_df[fish_df["Common Name"] == name_b].iloc[0]
            feature = build_feature(fish_a, fish_b)
            prediction = model.predict(feature)[0]

            if prediction == 0:
                reason = get_reason(fish_a, fish_b)
                incompatible.append({
                    "pair": [name_a, name_b],
                    "reason": reason
                })
            else:
                compatible_pairs.append([name_a, name_b])

    # Determine which fish are all pairwise compatible
    incompatible_set = {tuple(pair["pair"]) for pair in incompatible}
    compatible_group = [
        name for name in names
        if all((name, other) not in incompatible_set and (other, name) not in incompatible_set
               for other in names if other != name)
    ]

    return {
        "Fish Input": names,
        "Compatible Group": compatible_group,
        "Compatible Pairs": compatible_pairs,
        "Incompatible Pairs": incompatible
    }
