import pandas as pd
import numpy as np
from itertools import combinations
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score, classification_report
import joblib

# Load your dataset
df = pd.read_csv('app/datasets/fish_species_dataset.csv')

# Encode categorical features
le_temperament = LabelEncoder()
le_water = LabelEncoder()
le_diet = LabelEncoder()

df['Temperament'] = le_temperament.fit_transform(df['Temperament'])
df['Water Type'] = le_water.fit_transform(df['Water Type'])
df['Diet'] = le_diet.fit_transform(df['Diet'])

# Rename size for clarity
df = df.rename(columns={'Max Size (cm)': 'Size'})

# Create pairwise combinations
pairs = list(combinations(df.index, 2))

data = []
labels = []

for i, j in pairs:
    fish1 = df.loc[i]
    fish2 = df.loc[j]

    features = {
        'size_diff': abs(fish1['Size'] - fish2['Size']),
        'temperament_diff': abs(fish1['Temperament'] - fish2['Temperament']),
        'water_type_match': 1 if fish1['Water Type'] == fish2['Water Type'] else 0,
        'diet_match': 1 if fish1['Diet'] == fish2['Diet'] else 0
    }

    # Compatibility rules
    compatible = (
        features['size_diff'] <= 5 and
        features['temperament_diff'] <= 1 and
        features['water_type_match'] == 1 and
        features['diet_match'] == 1
    )


    data.append(features)
    labels.append(1 if compatible else 0)

# Convert to DataFrame
X = pd.DataFrame(data)
y = np.array(labels)

# Split for evaluation
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Evaluate
y_pred = model.predict(X_test)
print("Accuracy:", accuracy_score(y_test, y_pred))
print(classification_report(y_test, y_pred))

# Save the model
joblib.dump(model, 'random_forest_fish_compatibility.pkl')
print("✅ Model saved as 'random_forest_fish_compatibility.pkl'")

joblib.dump(le_temperament, 'encoder_temperament.pkl')
joblib.dump(le_water, 'encoder_water_type.pkl')
joblib.dump(le_diet, 'encoder_diet.pkl')

