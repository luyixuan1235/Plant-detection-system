from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
import os
import uuid
from app.core.database import get_db
from app.core.security import get_current_user, get_current_admin
from app.models.models import Floor, Seat, Report, ReportImage, User
from app.schemas.schemas import FloorResponse, SeatResponse, AnomalyResponse, ReportResponse

router = APIRouter(prefix="", tags=["Floors & Seats"])

def to_seat_response(s: Seat) -> SeatResponse:
    return SeatResponse(
        seat_id=s.seat_id,
        floor_id=s.floor_id,
        has_power=s.has_power,
        is_empty=s.is_empty,
        is_reported=s.is_reported,
        is_malicious=s.is_malicious,
        lock_until_ts=s.lock_until_ts,
        seat_color=s.seat_color,
        admin_color=s.admin_color,
    )

def to_floor_response(f: Floor) -> FloorResponse:
    return FloorResponse(
        floor_id=f.floor_id,
        empty_count=f.empty_count,
        total_count=f.total_count,
        floor_color=f.floor_color,
    )

def to_report_response(
    db: Session,
    r: Report,
    detection_result: Optional[dict] = None,
    treatment_plan: Optional[str] = None,
) -> ReportResponse:
    images = db.query(ReportImage).filter(ReportImage.report_id == r.id).all()
    paths = [img.path for img in images]
    return ReportResponse(
        id=r.id,
        seat_id=r.seat_id,
        reporter_id=r.reporter_id,
        text=r.text,
        images=paths,
        status=r.status,
        created_at=int(r.created_at.timestamp()),
        disease_name=detection_result.get("disease_name") if detection_result else None,
        is_diseased=detection_result.get("is_diseased") if detection_result else None,
        confidence=detection_result.get("confidence") if detection_result else None,
        treatment_plan=treatment_plan,
    )

@router.get("/floors", response_model=List[FloorResponse])
def get_floors(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    floors = db.query(Floor).all()
    return [to_floor_response(f) for f in floors]

@router.post("/floors/{floor}/refresh", response_model=List[SeatResponse])
def refresh_floor(floor: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    seats = db.query(Seat).filter(Seat.floor_id == floor).all()
    floor_row = db.query(Floor).filter(Floor.floor_id == floor).first()
    if floor_row:
        floor_row.total_count = db.query(Seat).filter(Seat.floor_id == floor).count()
        floor_row.empty_count = db.query(Seat).filter(Seat.floor_id == floor, Seat.is_empty == True).count()
        db.commit()
        db.refresh(floor_row)
    return [to_seat_response(s) for s in seats]

@router.get("/seats", response_model=List[SeatResponse])
def get_seats(floor: Optional[str] = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    q = db.query(Seat)
    if floor:
        q = q.filter(Seat.floor_id == floor)
    seats = q.all()
    return [to_seat_response(s) for s in seats]

@router.get("/admin/anomalies", response_model=List[AnomalyResponse])
def get_anomalies(floor: Optional[str] = None, db: Session = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    q = db.query(Seat).filter((Seat.is_reported == True) | (Seat.is_malicious == True))
    if floor:
        q = q.filter(Seat.floor_id == floor)
    seats = q.all()
    out: List[AnomalyResponse] = []
    for s in seats:
        last_report = db.query(Report).filter(Report.seat_id == s.seat_id).order_by(Report.created_at.desc()).first()
        last_id = last_report.id if last_report else None
        out.append(AnomalyResponse(**to_seat_response(s).dict(), last_report_id=last_id))
    return out

@router.get("/admin/reports/{report_id}", response_model=ReportResponse)
def get_report(report_id: int, db: Session = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    r = db.query(Report).filter(Report.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Report not found")
    return to_report_response(db, r)

@router.post("/admin/reports/{report_id}/confirm", response_model=ReportResponse)
def confirm_report(report_id: int, db: Session = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    r = db.query(Report).filter(Report.id == report_id).first()
    if not r:
        raise HTTPException(status_code=404, detail="Report not found")
    r.status = "confirmed"
    seat = db.query(Seat).filter(Seat.seat_id == r.seat_id).first()
    if seat:
        seat.is_reported = False
        seat.admin_color = "#FFFFFF"
    db.commit()
    db.refresh(r)
    return to_report_response(db, r)

@router.delete("/admin/anomalies/{seat_id}", response_model=AnomalyResponse)
def clear_anomaly(seat_id: str, db: Session = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    s = db.query(Seat).filter(Seat.seat_id == seat_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Seat not found")
    s.is_reported = False
    s.is_malicious = False
    db.commit()
    last_report = db.query(Report).filter(Report.seat_id == s.seat_id).order_by(Report.created_at.desc()).first()
    last_id = last_report.id if last_report else None
    return AnomalyResponse(**to_seat_response(s).dict(), last_report_id=last_id)

@router.post("/admin/seats/{seat_id}/lock", response_model=SeatResponse)
def lock_seat(seat_id: str, minutes: int, db: Session = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    s = db.query(Seat).filter(Seat.seat_id == seat_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Seat not found")
    s.lock_until_ts = int((datetime.utcnow() + timedelta(minutes=minutes)).timestamp())
    db.commit()
    db.refresh(s)
    return to_seat_response(s)

@router.post("/reports", response_model=ReportResponse)
async def create_report(
    seat_id: str = Form(...),
    reporter_id: int = Form(...),
    text: Optional[str] = Form(None),
    images: Optional[List[UploadFile]] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from app.services.disease_detection import disease_detector
    from app.services.deepseek_client import deepseek_client

    # Detect disease from first image if provided.
    detection_result = None
    treatment_plan = None
    if images and len(images) > 0:
        first_image = images[0]
        if first_image.content_type and not first_image.content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file must be an image",
            )

        temp_dir = os.path.join("app", "static", "temp")
        os.makedirs(temp_dir, exist_ok=True)
        _, ext = os.path.splitext(first_image.filename or "")
        temp_path = os.path.join(temp_dir, f"{uuid.uuid4()}{ext or '.jpg'}")
        try:
            with open(temp_path, "wb") as f:
                content = await first_image.read()
                f.write(content)

            detection_result = disease_detector.predict(temp_path)

            if detection_result.get("is_diseased"):
                treatment_plan = await deepseek_client.get_treatment_plan(
                    detection_result.get("disease_name")
                )
        except FileNotFoundError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Model file not found: {exc}",
            ) from exc
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            await first_image.seek(0)

    # Create report with disease info
    report_text = text or ""
    if detection_result:
        result_lines = [
            f"Disease: {detection_result.get('disease_name')}",
            f"Status: {'Diseased' if detection_result.get('is_diseased') else 'Healthy'}",
            f"Confidence: {detection_result.get('confidence', 0):.2%}",
        ]
        if treatment_plan:
            result_lines.extend(["", "Treatment Plan:", treatment_plan])
        if report_text:
            result_lines.extend(["", "User Note:", report_text])
        report_text = "\n".join(result_lines)

    r = Report(seat_id=seat_id, reporter_id=reporter_id, text=report_text, status="pending")
    db.add(r)
    db.commit()
    db.refresh(r)

    if images:
        base_dir = os.path.join("app", "static", "reports", str(r.id))
        os.makedirs(base_dir, exist_ok=True)
        for uf in images:
            filename = os.path.basename(uf.filename or f"image_{len(images)}")
            fs_path = os.path.join(base_dir, filename)
            with open(fs_path, "wb") as out:
                out.write(await uf.read())
            web_path = os.path.join("static", "reports", str(r.id), filename).replace("\\", "/")
            db.add(ReportImage(report_id=r.id, path=web_path))
        db.commit()

    seat = db.query(Seat).filter(Seat.seat_id == seat_id).first()
    if seat:
        seat.is_reported = True
        seat.admin_color = "#FFFF00"
        db.commit()

    return to_report_response(db, r, detection_result=detection_result, treatment_plan=treatment_plan)
