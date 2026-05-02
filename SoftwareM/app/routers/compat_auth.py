from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from app.core.database import get_db
from app.core.security import authenticate_user, create_access_token, get_password_hash
from app.core.config import settings
from app.models.models import User
from app.schemas.schemas import LoginResponse, RegisterRequest

router = APIRouter(prefix="", tags=["CompatAuth"])

@router.post("/auth/login", response_model=LoginResponse)
def compat_login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(data={"sub": user.username}, expires_delta=access_token_expires)
    role = "admin" if user.is_admin else "user"
    return {"access_token": access_token, "role": role, "username": user.username, "user_id": user.id}

@router.post("/auth/register", response_model=LoginResponse, status_code=status.HTTP_201_CREATED)
def compat_register(payload: RegisterRequest, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.username == payload.username).first()
    if db_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already registered")

    email = payload.email or f"{payload.username}@local"
    db_email_user = db.query(User).filter(User.email == email).first()
    if db_email_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    hashed_password = get_password_hash(payload.password)
    new_user = User(username=payload.username, email=email, hashed_password=hashed_password, is_admin=False)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(data={"sub": new_user.username}, expires_delta=access_token_expires)
    return {"access_token": access_token, "role": "user", "username": new_user.username, "user_id": new_user.id}

@router.post("/auth/logout")
def compat_logout():
    return {"ok": True}
