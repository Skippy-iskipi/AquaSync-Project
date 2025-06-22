from fastapi import APIRouter, Depends, HTTPException, Response
from typing import List, Optional
from app.supabase_config import get_supabase_client
from supabase import Client
import base64
import random

router = APIRouter(
    prefix="/fish-images",
    tags=["fish-images"],
    responses={404: {"description": "Not found"}},
)

@router.get("/species")
def get_fish_species(db: Client = Depends(get_supabase_client)):
    """Get a list of all fish species with images in the database"""
    response = db.table('fish_images_dataset').select('common_name').execute()
    species = list({item['common_name'] for item in response.data if item.get('common_name')})
    return {"species": species}

@router.get("/stats")
def get_image_stats(db: Client = Depends(get_supabase_client)):
    """Get statistics about the image dataset"""
    response = db.table('fish_images_dataset').select('*').execute()
    images = response.data if response.data else []
    total_images = len(images)
    by_species = {}
    by_dataset = {}
    for img in images:
        species = img.get('common_name')
        dataset_type = img.get('dataset_type', 'unknown')
        by_species[species] = by_species.get(species, 0) + 1
        by_dataset[dataset_type] = by_dataset.get(dataset_type, 0) + 1
    return {
        "total_images": total_images,
        "by_dataset": by_dataset,
        "by_species": by_species
    }

@router.get("/image/{image_id}")
def get_image(image_id: int, db: Client = Depends(get_supabase_client)):
    """Get a specific image by ID"""
    response = db.table('fish_images_dataset').select('*').eq('id', image_id).limit(1).execute()
    images = response.data if response.data else []
    if not images:
        raise HTTPException(status_code=404, detail="Image not found")
    image_data = images[0].get('image_data')
    if not image_data:
        raise HTTPException(status_code=404, detail="Image data not found")
    return Response(content=base64.b64decode(image_data), media_type="image/jpeg")

@router.get("/image/{image_id}/base64")
def get_image_base64(image_id: int, db: Client = Depends(get_supabase_client)):
    """Get a specific image by ID as base64 string"""
    response = db.table('fish_images_dataset').select('*').eq('id', image_id).limit(1).execute()
    images = response.data if response.data else []
    if not images:
        raise HTTPException(status_code=404, detail="Image not found")
    image_data = images[0].get('image_data')
    if not image_data:
        raise HTTPException(status_code=404, detail="Image data not found")
    return {"image_data": f"data:image/jpeg;base64,{image_data}"}

@router.get("/species/{species_name}")
def get_species_images(
    species_name: str,
    dataset_type: Optional[str] = None,
    limit: int = 10,
    offset: int = 0,
    db: Client = Depends(get_supabase_client)
):
    """Get images for a specific fish species with pagination"""
    query = db.table('fish_images_dataset').select('*').ilike('common_name', species_name)
    if dataset_type:
        query = query.eq('dataset_type', dataset_type)
    response = query.execute()
    images = response.data if response.data else []
    total = len(images)
    paginated = images[offset:offset+limit]
    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "images": [
            {
                "id": img['id'],
                "species": img.get('common_name'),
                "filename": img.get('image_name'),
                "dataset_type": img.get('dataset_type'),
                "image_url": f"/fish-images/image/{img['id']}"
            }
            for img in paginated
        ]
    }

@router.get("/random/{dataset_type}")
def get_random_images(
    dataset_type: str,
    limit: int = 10,
    db: Client = Depends(get_supabase_client)
):
    """Get random images from a specific dataset type"""
    response = db.table('fish_images_dataset').select('*').eq('dataset_type', dataset_type).execute()
    images = response.data if response.data else []
    if not images:
        return {"dataset_type": dataset_type, "count": 0, "images": []}
    random.shuffle(images)
    selected = images[:limit]
    return {
        "dataset_type": dataset_type,
        "count": len(selected),
        "images": [
            {
                "id": img['id'],
                "species": img.get('common_name'),
                "filename": img.get('image_name'),
                "image_url": f"/fish-images/image/{img['id']}"
            }
            for img in selected
        ]
    }
