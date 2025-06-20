from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import torch
from torchvision import transforms
from torchvision.models import efficientnet_b3, EfficientNet_B3_Weights
from PIL import Image, UnidentifiedImageError
import pandas as pd
import io
import os
from pathlib import Path

app = FastAPI()

# Enable CORS if needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load fish metadata CSV
df = pd.read_csv("backend/app/datasets/aquarium_fish_dataset_cleaned_final.csv")
df["Common Name Lower"] = df["Common Name"].str.lower()

# Dynamically get class names from folder structure
TRAIN_DIR = "backend/app/datasets/fish_images/train"
class_names = sorted([f.name for f in Path(TRAIN_DIR).iterdir() if f.is_dir()])

# Mapping: class_idx -> Common Name
def format_classname(name):
    return name.replace("_", " ").lower()

idx_to_common_name = {i: format_classname(name) for i, name in enumerate(class_names)}

# Load the model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = efficientnet_b3(weights=EfficientNet_B3_Weights.IMAGENET1K_V1)
model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, len(class_names))
model.load_state_dict(torch.load("backend/app/models/trained_models/efficientnet_b3_fish_classifier.pth", map_location=device))
model.to(device)
model.eval()

# Preprocessing pipeline
transform = transforms.Compose([
    transforms.Resize(320),
    transforms.CenterCrop(300),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png"}
MAX_FILE_SIZE_MB = 5

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    filename = file.filename.lower()
    ext = filename.split(".")[-1]
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid file type. Only JPG/PNG allowed.")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large. Max {MAX_FILE_SIZE_MB}MB allowed.")

    try:
        image = Image.open(io.BytesIO(contents)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Uploaded file is not a valid image.")

    input_tensor = transform(image).unsqueeze(0).to(device)

    try:
        with torch.no_grad():
            outputs = model(input_tensor)
            probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
            confidence, pred_idx = torch.max(probabilities, 0)
            class_idx = pred_idx.item()
            score = confidence.item()

        common_name = idx_to_common_name[class_idx]
        match = df[df["Common Name Lower"] == common_name]

        if match.empty:
            return JSONResponse(status_code=404, content={"detail": "Fish info not found in CSV."})

        fish = match.iloc[0]
        return {
            "common_name": fish["Common Name"],
            "scientific_name": fish["Scientific Name"],
            "water_type": fish["Water Type"],
            "confidence": round(score, 4)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
