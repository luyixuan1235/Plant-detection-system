from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.core.security import get_current_admin
from app.models.models import User, Patrol
from app.schemas.schemas import PatrolCreate, PatrolResponse

router = APIRouter(prefix="/api/patrols", tags=["Patrols"])

@router.post("/checkin", response_model=PatrolResponse, status_code=status.HTTP_201_CREATED)
def checkin_patrol(
    patrol: PatrolCreate,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    new_patrol = Patrol(
        admin_id=current_admin.id,
        latitude=patrol.latitude,
        longitude=patrol.longitude,
        notes=patrol.notes
    )
    db.add(new_patrol)
    db.commit()
    db.refresh(new_patrol)
    return new_patrol

@router.get("/", response_model=List[PatrolResponse])
def get_patrols(
    skip: int = 0,
    limit: int = 100,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    patrols = db.query(Patrol).filter(Patrol.admin_id == current_admin.id).offset(skip).limit(limit).all()
    return patrols

@router.get("/all", response_model=List[PatrolResponse])
def get_all_patrols(
    skip: int = 0,
    limit: int = 100,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    patrols = db.query(Patrol).offset(skip).limit(limit).all()
    return patrols
