from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List
import os
import uuid
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.models import User, Tree
from app.schemas.schemas import TreeResponse, DiseaseDetectionResponse
from app.services.disease_detection import disease_detector
from app.services.deepseek_client import deepseek_client
from app.core.config import settings

router = APIRouter(prefix="/api/trees", tags=["Trees"])

@router.post("/detect", response_model=TreeResponse, status_code=status.HTTP_201_CREATED)
async def detect_disease(
    location_name: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Validate file type
    if not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image"
        )

    # Save uploaded image
    os.makedirs(settings.upload_dir, exist_ok=True)
    file_extension = os.path.splitext(image.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = os.path.join(settings.upload_dir, unique_filename)

    with open(file_path, "wb") as buffer:
        content = await image.read()
        buffer.write(content)

    # Detect disease
    detection_result = disease_detector.predict(file_path)

    # Get treatment plan if diseased
    treatment_plan = None
    if detection_result["is_diseased"]:
        treatment_plan = await deepseek_client.get_treatment_plan(detection_result["disease_name"])

    # Save to database
    new_tree = Tree(
        location_name=location_name,
        latitude=latitude,
        longitude=longitude,
        image_path=file_path,
        disease_name=detection_result["disease_name"],
        is_diseased=detection_result["is_diseased"],
        treatment_plan=treatment_plan,
        status="treating" if detection_result["is_diseased"] else "healthy",
        reported_by=current_user.id
    )
    db.add(new_tree)
    db.commit()
    db.refresh(new_tree)

    return new_tree

@router.get("/", response_model=List[TreeResponse])
def get_all_trees(
    skip: int = 0,
    limit: int = 100,
    diseased_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Tree)
    if diseased_only:
        query = query.filter(Tree.is_diseased == True)
    trees = query.offset(skip).limit(limit).all()
    return trees

@router.get("/{tree_id}", response_model=TreeResponse)
def get_tree(
    tree_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    tree = db.query(Tree).filter(Tree.id == tree_id).first()
    if not tree:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tree not found"
        )
    return tree

@router.put("/{tree_id}/status", response_model=TreeResponse)
def update_tree_status(
    tree_id: int,
    new_status: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if new_status not in ["pending", "treating", "recovered", "healthy"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid status"
        )

    tree = db.query(Tree).filter(Tree.id == tree_id).first()
    if not tree:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tree not found"
        )

    tree.status = new_status
    db.commit()
    db.refresh(tree)
    return tree
