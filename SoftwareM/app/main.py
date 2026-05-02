from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.core.database import engine, Base
from app.routers import auth, trees, patrols
from app.routers.compat_auth import router as compat_auth_router
from app.routers.floors import router as floors_router
import os

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Campus Plant Management System",
    description="API for managing campus plant health and disease detection",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
os.makedirs("app/static/uploads", exist_ok=True)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# Include routers
app.include_router(auth.router)
app.include_router(trees.router)
app.include_router(patrols.router)
app.include_router(compat_auth_router)
app.include_router(floors_router)

@app.get("/")
def root():
    return {
        "message": "Welcome to Campus Plant Management System API",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}
