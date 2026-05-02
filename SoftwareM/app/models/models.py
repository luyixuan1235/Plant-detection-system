from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    trees = relationship("Tree", back_populates="reporter")
    patrols = relationship("Patrol", back_populates="admin")

class Tree(Base):
    __tablename__ = "trees"

    id = Column(Integer, primary_key=True, index=True)
    location_name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    image_path = Column(String, nullable=False)
    disease_name = Column(String, nullable=True)
    is_diseased = Column(Boolean, default=False)
    treatment_plan = Column(Text, nullable=True)
    status = Column(String, default="pending")
    reported_by = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    reporter = relationship("User", back_populates="trees")

class Patrol(Base):
    __tablename__ = "patrols"

    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    admin = relationship("User", back_populates="patrols")

class Floor(Base):
    __tablename__ = "floors"

    id = Column(Integer, primary_key=True, index=True)
    floor_id = Column(String, unique=True, index=True, nullable=False)
    total_count = Column(Integer, default=0)
    empty_count = Column(Integer, default=0)
    floor_color = Column(String, default="#00AAFF")
    created_at = Column(DateTime, default=datetime.utcnow)

class Seat(Base):
    __tablename__ = "seats"

    id = Column(Integer, primary_key=True, index=True)
    seat_id = Column(String, unique=True, index=True, nullable=False)
    floor_id = Column(String, ForeignKey("floors.floor_id"), nullable=False)
    has_power = Column(Boolean, default=True)
    is_empty = Column(Boolean, default=True)
    is_reported = Column(Boolean, default=False)
    is_malicious = Column(Boolean, default=False)
    lock_until_ts = Column(Integer, nullable=True)
    seat_color = Column(String, default="#00FF00")
    admin_color = Column(String, default="#FFFFFF")
    created_at = Column(DateTime, default=datetime.utcnow)

class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    seat_id = Column(String, ForeignKey("seats.seat_id"), nullable=False)
    reporter_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    text = Column(Text, nullable=True)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

class ReportImage(Base):
    __tablename__ = "report_images"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, ForeignKey("reports.id"), nullable=False)
    path = Column(String, nullable=False)
