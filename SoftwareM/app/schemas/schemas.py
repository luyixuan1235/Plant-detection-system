from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional, List

# User Schemas
class UserBase(BaseModel):
    username: str
    email: EmailStr

class UserCreate(UserBase):
    password: str
    is_admin: bool = False

class UserLogin(BaseModel):
    username: str
    password: str

class UserResponse(UserBase):
    id: int
    is_admin: bool
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class LoginResponse(BaseModel):
    access_token: str
    role: str
    username: str
    user_id: int

class RegisterRequest(BaseModel):
    username: str
    password: str
    email: Optional[EmailStr] = None

# Tree Schemas
class TreeBase(BaseModel):
    location_name: str
    latitude: float
    longitude: float

class TreeCreate(TreeBase):
    pass

class TreeResponse(TreeBase):
    id: int
    image_path: str
    disease_name: Optional[str] = None
    is_diseased: bool
    treatment_plan: Optional[str] = None
    status: str
    reported_by: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class DiseaseDetectionResponse(BaseModel):
    disease_name: str
    is_diseased: bool
    confidence: float
    treatment_plan: Optional[str] = None

# Patrol Schemas
class PatrolBase(BaseModel):
    latitude: float
    longitude: float
    notes: Optional[str] = None

class PatrolCreate(PatrolBase):
    pass

class PatrolResponse(PatrolBase):
    id: int
    admin_id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Seating/Floor/Reports schemas
class SeatResponse(BaseModel):
    seat_id: str
    floor_id: str
    has_power: bool
    is_empty: bool
    is_reported: bool
    is_malicious: bool
    lock_until_ts: Optional[int] = None
    seat_color: str
    admin_color: str

class FloorResponse(BaseModel):
    floor_id: str
    empty_count: int
    total_count: int
    floor_color: str

class AnomalyResponse(SeatResponse):
    last_report_id: Optional[int] = None

class ReportResponse(BaseModel):
    id: int
    seat_id: str
    reporter_id: int
    text: Optional[str] = None
    images: List[str]
    status: str
    created_at: int
    disease_name: Optional[str] = None
    is_diseased: Optional[bool] = None
    confidence: Optional[float] = None
    treatment_plan: Optional[str] = None
