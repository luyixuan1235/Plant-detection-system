from __future__ import annotations

import time
from pathlib import Path
from typing import List, Optional

from fastapi import APIRouter, Depends, Form, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Report, Seat
from ..schemas import ReportOut
from ..services.disease_detection import disease_detector
from ..services.deepseek_service import deepseek_service


router = APIRouter(prefix="", tags=["reports"])


def _save_report_images(report_id: int, files: Optional[List[UploadFile]]) -> List[str]:
	print(f"DEBUG _save_report_images: report_id={report_id}, files={files}")
	if not files:
		print("DEBUG _save_report_images: No files provided, returning empty list")
		return []
	
	base_dir = Path(__file__).resolve().parents[2]
	report_root = base_dir / "config" / "report" / str(report_id)
	print(f"DEBUG _save_report_images: base_dir={base_dir}")
	print(f"DEBUG _save_report_images: report_root={report_root}")
	
	report_root.mkdir(parents=True, exist_ok=True)
	print(f"DEBUG _save_report_images: Created directory: {report_root}")
	
	now = int(time.time())
	saved: List[str] = []
	allowed_exts = {'.jpg', '.jpeg', '.png'}
	
	print(f"DEBUG _save_report_images: Processing {len(files)} file(s)")
	for idx, f in enumerate(files):
		print(f"DEBUG _save_report_images: Processing file[{idx}]: filename={f.filename}, content_type={f.content_type}")
		
		# Relaxed content-type check for Flutter Web compatibility
		is_image = f.content_type and f.content_type.startswith("image/")
		ext = Path(f.filename or "").suffix.lower()
		print(f"DEBUG _save_report_images: File[{idx}] - is_image={is_image}, ext={ext}")
		
		if not is_image:
			# Fallback: check extension if content-type is generic or missing
			if ext in allowed_exts:
				is_image = True
				print(f"DEBUG _save_report_images: File[{idx}] - Accepted by extension fallback")
		
		# Strict extension check as requested
		if ext not in allowed_exts:
			print(f"ERROR: Rejected file extension: {f.filename}, type: {f.content_type}, ext: {ext}")
			raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported file extension: {ext}. Only jpg/jpeg/png allowed.")

		if not is_image:
			print(f"ERROR: Rejected file type: {f.filename}, type: {f.content_type}")
			raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported file type: {f.content_type}")
		
		# Use original extension or default to .jpg
		if not ext: 
			ext = ".jpg"
			
		filename = f"{now}_{idx}{ext}"
		target_path = report_root / filename
		print(f"DEBUG _save_report_images: Saving file[{idx}] to: {target_path}")
		
		try:
			# Read file content
			file_content = f.file.read()
			file_size = len(file_content)
			print(f"DEBUG _save_report_images: File[{idx}] size: {file_size} bytes")
			
			# Write to disk
			with target_path.open("wb") as out:
				out.write(file_content)
			
			print(f"DEBUG _save_report_images: Successfully saved file[{idx}] to: {target_path}")
			
			# Verify file was written
			if target_path.exists():
				actual_size = target_path.stat().st_size
				print(f"DEBUG _save_report_images: Verified file[{idx}] exists, size: {actual_size} bytes")
			else:
				print(f"ERROR: File[{idx}] was not created at: {target_path}")
			
		except Exception as e:
			print(f"ERROR: Failed to save file[{idx}]: {type(e).__name__}: {e}")
			raise
		
		# store as path relative to config/report for static serving via /report
		saved.append(f"report/{report_id}/{filename}")
	
	print(f"DEBUG _save_report_images: Successfully saved {len(saved)} file(s)")
	return saved


@router.post("/reports", response_model=ReportOut)
async def create_report(
	seat_id: str = Form(...),
	reporter_id: int = Form(...),
	text: Optional[str] = Form(default=None),
	images: Optional[List[UploadFile]] = File(default=None),
	db: Session = Depends(get_db),
) -> ReportOut:
	print("=" * 60)
	print(f"DEBUG: Received report for seat_id={seat_id}, reporter_id={reporter_id}")
	print(f"DEBUG: Text: {text}")
	print(f"DEBUG: Images parameter type: {type(images)}")
	print(f"DEBUG: Images received: {len(images) if images else 0}")
	now = int(time.time())
	
	if images:
		print(f"DEBUG: Processing {len(images)} image(s)...")
		for idx, img in enumerate(images):
			print(f"DEBUG: Image[{idx}] - Filename: {img.filename}, Content-Type: {img.content_type}, Size: {img.size if hasattr(img, 'size') else 'unknown'}")
	else:
		print("DEBUG: No images provided (images is None or empty)")

	seat = db.query(Seat).filter(Seat.seat_id == seat_id).first()
	if not seat:
		if not seat_id.upper().startswith("T"):
			raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="seat_id not found")
		seat = Seat(
			seat_id=seat_id,
			floor_id="PLANT",
			has_power=False,
			is_empty=True,
			is_reported=False,
			is_malicious=False,
			lock_until_ts=0,
			last_update_ts=now,
			last_state_is_empty=True,
			daily_empty_seconds=0,
			total_empty_seconds=0,
			change_count=0,
			occupancy_start_ts=0,
		)
		db.add(seat)
		db.flush()

	report = Report(
		seat_id=seat_id,
		reporter_id=reporter_id,
		text=text,
		images=[],
		status="pending",
		created_at=now,
	)
	db.add(report)
	db.flush()  # to get report.id
	print(f"DEBUG: Created report with ID: {report.id}")

	try:
		print(f"DEBUG: Calling _save_report_images with report_id={report.id}, files={images}")
		image_paths = _save_report_images(report.id, images)
		print(f"DEBUG: Saved {len(image_paths)} image(s): {image_paths}")
	except HTTPException as e:
		print(f"DEBUG: Error saving images: {e.detail}")
		db.rollback()
		raise
	except Exception as e:
		print(f"DEBUG: Unexpected error saving images: {type(e).__name__}: {e}")
		db.rollback()
		raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to save images: {str(e)}")

	detection_result = None
	treatment_plan = None
	if image_paths:
		first_image_path = Path(__file__).resolve().parents[2] / "config" / image_paths[0]
		try:
			detection_result = disease_detector.predict(first_image_path)
			result_lines = [
				f"Disease: {detection_result.get('disease_name')}",
				f"Status: {'Diseased' if detection_result.get('is_diseased') else 'Healthy'}",
				f"Confidence: {detection_result.get('confidence', 0):.2%}",
			]

			if detection_result.get('is_diseased'):
				treatment_plan = await deepseek_service.get_treatment_advice(
					detection_result.get('disease_name')
				)

			if text:
				result_lines.extend(["", "User Note:", text])
			report.text = "\n".join(result_lines)
		except FileNotFoundError as e:
			db.rollback()
			raise HTTPException(
				status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
				detail=f"Model file not found: {e}",
			)
		except Exception as e:
			db.rollback()
			raise HTTPException(
				status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
				detail=f"Disease prediction failed: {type(e).__name__}: {e}",
			)

	report.images = image_paths
	seat.is_reported = True

	# Update seat disease status
	if detection_result:
		seat.is_diseased = detection_result.get('is_diseased', False)
		seat.disease_name = detection_result.get('disease_name')
		seat.disease_confidence = detection_result.get('confidence')
		seat.last_disease_check_ts = now

	db.add(report)
	db.add(seat)
	db.commit()
	db.refresh(report)

	print(f"DEBUG: Report saved successfully. Images: {report.images}")
	print("=" * 60)
	response = ReportOut.model_validate(report)
	if detection_result:
		response.disease_name = detection_result.get("disease_name")
		response.is_diseased = detection_result.get("is_diseased")
		response.confidence = detection_result.get("confidence")
		response.treatment_plan = treatment_plan
	return response


