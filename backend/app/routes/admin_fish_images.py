from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models.image_dataset import ImageDataset, DatasetType
import io
from PIL import Image
import base64
import logging
from sqlalchemy import func

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/admin/fish-images",
    tags=["admin-fish-images"],
    responses={404: {"description": "Not found"}},
)

@router.get("/images")
def get_all_fish_images(
    species: Optional[str] = None,
    dataset_type: Optional[str] = None,
    limit: int = 10,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    """Admin endpoint to get all fish images with pagination and filtering"""
    query = db.query(ImageDataset)
    
    # Apply filters
    if species:
        query = query.filter(ImageDataset.fish_name == species)
    
    if dataset_type:
        try:
            dt = DatasetType(dataset_type)
            query = query.filter(ImageDataset.dataset_type == dt)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid dataset type. Must be one of: {[t.value for t in DatasetType]}"
            )
    
    # Apply pagination
    images = query.order_by(ImageDataset.id).offset(offset).limit(limit).all()
    
    return {
        "images": [
            {
                "id": img.id,
                "species": img.fish_name,
                "filename": img.image_name,
                "dataset_type": img.dataset_type.value,
                "created_at": img.created_at,
                "updated_at": img.updated_at
            }
            for img in images
        ]
    }

@router.post("/images")
async def upload_fish_image(
    file: UploadFile = File(...),
    species: str = Form(...),
    dataset_type: str = Form(...),
    db: Session = Depends(get_db)
):
    """Admin endpoint to upload a new fish image"""
    try:
        # Validate dataset type
        try:
            dt = DatasetType(dataset_type)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid dataset type. Must be one of: {[t.value for t in DatasetType]}"
            )
        
        # Validate file is an image
        if not file.content_type.startswith("image/"):
            raise HTTPException(
                status_code=400,
                detail="Uploaded file is not an image"
            )
        
        try:
            # Read image data
            contents = await file.read()
            
            # Validate image can be opened
            try:
                img = Image.open(io.BytesIO(contents))
                img.verify()  # Verify it's a valid image
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid image file: {str(e)}"
                )
            
            # Create new ImageDataset record
            fish_image = ImageDataset(
                fish_name=species,
                image_name=file.filename,
                image_data=contents,
                dataset_type=dt
            )
            
            db.add(fish_image)
            db.commit()
            db.refresh(fish_image)
            
            return {
                "id": fish_image.id,
                "species": fish_image.fish_name,
                "filename": fish_image.image_name,
                "dataset_type": fish_image.dataset_type.value,
                "message": "Image uploaded successfully"
            }
        
        except HTTPException as e:
            raise e
        except Exception as e:
            db.rollback()
            logger.error(f"Error uploading image: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to upload image: {str(e)}"
            )

    except Exception as e:
        logger.error(f"Error uploading image: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to upload image: {str(e)}"
        )

@router.delete("/{image_id}")
def delete_fish_image(image_id: int, db: Session = Depends(get_db)):
    """Admin endpoint to delete a fish image"""
    image = db.query(ImageDataset).filter(ImageDataset.id == image_id).first()
    
    if not image:
        raise HTTPException(
            status_code=404,
            detail="Image not found"
        )
    
    try:
        db.delete(image)
        db.commit()
        
        return {
            "message": f"Image {image_id} deleted successfully"
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error deleting image: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete image: {str(e)}"
        )

@router.put("/{image_id}")
def update_fish_image_metadata(
    image_id: int,
    species: Optional[str] = None,
    dataset_type: Optional[str] = None,
    filename: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Admin endpoint to update fish image metadata"""
    image = db.query(ImageDataset).filter(ImageDataset.id == image_id).first()
    
    if not image:
        raise HTTPException(
            status_code=404,
            detail="Image not found"
        )
    
    try:
        # Update species if provided
        if species is not None:
            image.fish_name = species
        
        # Update dataset type if provided
        if dataset_type is not None:
            try:
                dt = DatasetType(dataset_type)
                image.dataset_type = dt
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid dataset type. Must be one of: {[dt.value for dt in DatasetType]}"
                )
        
        # Update filename if provided
        if filename is not None:
            # Ensure the filename has an extension
            if '.' not in filename:
                # Get extension from original filename
                original_ext = image.image_name.split('.')[-1] if '.' in image.image_name else 'jpg'
                filename = f"{filename}.{original_ext}"
            
            # Check if the new filename already exists (excluding the current image)
            existing_image = db.query(ImageDataset).filter(
                ImageDataset.image_name == filename,
                ImageDataset.id != image_id
            ).first()
            
            if existing_image:
                raise HTTPException(
                    status_code=400,
                    detail=f"Filename '{filename}' already exists for another image. Please choose a different name."
                )
                
            image.image_name = filename
        
        db.commit()
        db.refresh(image)
        
        return {
            "id": image.id,
            "species": image.fish_name,
            "filename": image.image_name,
            "dataset_type": image.dataset_type.value,
            "message": "Image metadata updated successfully"
        }
    
    except HTTPException as e:
        raise e
    except Exception as e:
        db.rollback()
        logger.error(f"Error updating image metadata: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update image metadata: {str(e)}"
        )

@router.post("/bulk-update")
def bulk_update_dataset_type(
    image_ids: List[int],
    dataset_type: str,
    db: Session = Depends(get_db)
):
    """Admin endpoint to update dataset type for multiple images"""
    # Validate dataset type
    try:
        dt = DatasetType(dataset_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid dataset type. Must be one of: {[dt.value for dt in DatasetType]}"
        )
    
    try:
        # Update all specified images
        updated = db.query(ImageDataset).filter(ImageDataset.id.in_(image_ids)).update(
            {ImageDataset.dataset_type: dt},
            synchronize_session=False
        )
        
        db.commit()
        
        return {
            "updated_count": updated,
            "message": f"Updated {updated} images to dataset type {dataset_type}"
        }
    
    except Exception as e:
        db.rollback()
        logger.error(f"Error in bulk update: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update images: {str(e)}"
        )

@router.get("/stats")
def get_dataset_stats(db: Session = Depends(get_db)):
    """Get statistics about the image dataset, including per-species per-dataset-type counts."""
    try:
        # Total images
        total_images = db.query(ImageDataset).count()

        # Count by species and dataset type
        detailed_counts = db.query(
            ImageDataset.fish_name,
            ImageDataset.dataset_type,
            func.count(ImageDataset.id)
        ).group_by(ImageDataset.fish_name, ImageDataset.dataset_type).all()

        # Build nested dict: {species: {dataset_type: count, ...}, ...}
        species_dataset_distribution = {}
        for species, dataset_type, count in detailed_counts:
            if species not in (None, "") and dataset_type is not None:
                if species not in species_dataset_distribution:
                    species_dataset_distribution[species] = {"train": 0, "val": 0, "test": 0}
                species_dataset_distribution[species][dataset_type.value] = count

        unique_species = len(species_dataset_distribution)

        return {
            "total_images": total_images,
            "unique_species": unique_species,
            "species_dataset_distribution": species_dataset_distribution
        }

    except Exception as e:
        logger.error(f"Error getting dataset stats: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get dataset statistics: {str(e)}"
        )
