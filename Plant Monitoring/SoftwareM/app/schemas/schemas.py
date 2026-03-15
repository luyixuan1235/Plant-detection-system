from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional

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
