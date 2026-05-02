from __future__ import annotations

import time
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..auth import require_admin
from ..db import get_db
from ..models import User, WateringCheckin
from ..schemas import WateringCheckinCreate, WateringCheckinOut


router = APIRouter(prefix="/admin/watering", tags=["watering"])


@router.post("/checkin", response_model=WateringCheckinOut)
def create_watering_checkin(
	payload: WateringCheckinCreate,
	admin_user: User = Depends(require_admin),
	db: Session = Depends(get_db),
) -> WateringCheckinOut:
	record = WateringCheckin(
		admin_user_id=admin_user.id,
		checkin_ts=int(time.time()),
		latitude=payload.latitude,
		longitude=payload.longitude,
	)
	db.add(record)
	db.commit()
	db.refresh(record)
	return WateringCheckinOut.model_validate(record)


@router.get("/checkins", response_model=List[WateringCheckinOut])
def list_watering_checkins(
	limit: int = Query(default=5, ge=1, le=20),
	admin_user: User = Depends(require_admin),
	db: Session = Depends(get_db),
) -> List[WateringCheckinOut]:
	records = (
		db.query(WateringCheckin)
		.filter(WateringCheckin.admin_user_id == admin_user.id)
		.order_by(WateringCheckin.checkin_ts.desc(), WateringCheckin.id.desc())
		.limit(limit)
		.all()
	)
	return [WateringCheckinOut.model_validate(item) for item in records]

