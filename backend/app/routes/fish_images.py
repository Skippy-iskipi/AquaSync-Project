from fastapi import APIRouter, Depends, HTTPException, Response, File, UploadFile
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models.image_dataset import ImageDataset, DatasetType
import io
from PIL import Image
import base64

router = APIRouter(
    prefix="/fish-images",
    tags=["fish-images"],
    responses={404: {"description": "Not found"}},
)

@router.get("/species")
def get_fish_species(db: Session = Depends(get_db)):
    """Get a list of all fish species with images in the database"""
    species = db.query(ImageDataset.fish_name).distinct().all()
    return {"species": [s[0] for s in species]}

@router.get("/stats")
def get_image_stats(db: Session = Depends(get_db)):
    """Get statistics about the image dataset"""
    # Count by dataset type
    dataset_counts = db.query(
        ImageDataset.dataset_type, 
        db.func.count(ImageDataset.id)
    ).group_by(ImageDataset.dataset_type).all()
    
    # Count by species
    species_counts = db.query(
        ImageDataset.fish_name, 
        db.func.count(ImageDataset.id)
    ).group_by(ImageDataset.fish_name).all()
    
    return {
        "total_images": db.query(ImageDataset).count(),
        "by_dataset": {dt[0].value: dt[1] for dt in dataset_counts},
        "by_species": {sp[0]: sp[1] for sp in species_counts}
    }

@router.get("/image/{image_id}")
def get_image(image_id: int, db: Session = Depends(get_db)):
    """Get a specific image by ID"""
    image = db.query(ImageDataset).filter(ImageDataset.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    
    return Response(content=image.image_data, media_type="image/jpeg")

@router.get("/image/{image_id}/base64")
def get_image_base64(image_id: int, db: Session = Depends(get_db)):
    """Get a specific image by ID as base64 string"""
    image = db.query(ImageDataset).filter(ImageDataset.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    
    base64_image = base64.b64encode(image.image_data).decode("utf-8")
    return {"image_data": f"data:image/jpeg;base64,{base64_image}"}

@router.get("/species/{species_name}")
def get_species_images(
    species_name: str,
    dataset_type: Optional[str] = None,
    limit: int = 10,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """Get images for a specific fish species with pagination"""
    query = db.query(ImageDataset).filter(ImageDataset.fish_name == species_name)
    
    if dataset_type:
        try:
            dt = DatasetType(dataset_type)
            query = query.filter(ImageDataset.dataset_type == dt)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid dataset type. Must be one of: {[t.value for t in DatasetType]}"
            )
    
    total = query.count()
    images = query.offset(offset).limit(limit).all()
    
    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "images": [
            {
                "id": img.id,
                "species": img.fish_name,
                "filename": img.image_name,
                "dataset_type": img.dataset_type.value,
                "image_url": f"/fish-images/image/{img.id}"
            }
            for img in images
        ]
    }

@router.get("/random/{dataset_type}")
def get_random_images(
    dataset_type: str,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """Get random images from a specific dataset type"""
    try:
        dt = DatasetType(dataset_type)
    except ValueError:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid dataset type. Must be one of: {[dt.value for dt in DatasetType]}"
        )
    
    # Get random images using database random function
    images = db.query(ImageDataset).filter(
        ImageDataset.dataset_type == dt
    ).order_by(db.func.random()).limit(limit).all()
    
    return {
        "dataset_type": dataset_type,
        "count": len(images),
        "images": [
            {
                "id": img.id,
                "species": img.fish_name,
                "filename": img.image_name,
                "image_url": f"/fish-images/image/{img.id}"
            }
            for img in images
        ]
    }
