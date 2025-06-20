import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib

# Load the labeled compatibility dataset
df = pd.read_csv("datasets/fish_pairwise_labeled_with_diet.csv")

# Drop non-numeric columns (Fish names) and prepare features
X = df.drop(columns=["Fish A", "Fish B", "Compatible"])
X = pd.get_dummies(X)  # Convert categorical data to numeric if needed
y = df["Compatible"]   # Target labels

# Split into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Train the Random Forest model
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Evaluate the model
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print("Accuracy:", accuracy)
print(classification_report(y_test, y_pred))

# Save the trained model to disk
joblib.dump(model, "trained_models/random_forest_model_with_diet.pkl")
print("✅ Model saved as random_forest_model_with_diet.pkl")
