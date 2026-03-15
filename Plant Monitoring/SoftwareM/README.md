# Campus Plant Management System - Backend

## Project Overview
This is the backend system for a campus plant health management application. It provides disease detection for trees using CNN models and integrates with DeepSeek API for treatment recommendations.

## Features
- User authentication (JWT-based)
- Role-based access control (User/Admin)
- Plant disease detection via image upload
- AI-powered treatment plan generation
- Geolocation tracking for diseased trees
- Admin patrol check-in system
- RESTful API with FastAPI

## Tech Stack
- Python 3.8+
- FastAPI
- SQLAlchemy
- PyTorch
- SQLite

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Edit `.env` and add your configuration:
- Set `SECRET_KEY` for JWT
- Add your `DEEPSEEK_API_KEY`
- Verify `MODEL_PATH` points to your trained model

## Running the Application

Start the server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Access the API documentation at: http://localhost:8000/docs

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/me` - Get current user info

### Trees
- `POST /api/trees/detect` - Upload image and detect disease
- `GET /api/trees/` - Get all trees (with optional filters)
- `GET /api/trees/{tree_id}` - Get specific tree details
- `PUT /api/trees/{tree_id}/status` - Update tree status

### Patrols (Admin only)
- `POST /api/patrols/checkin` - Check-in patrol location
- `GET /api/patrols/` - Get my patrol history
- `GET /api/patrols/all` - Get all patrol records

## Project Structure
```
app/
├── core/           # Core configurations
├── models/         # Database models
├── schemas/        # Pydantic schemas
├── routers/        # API routes
├── services/       # Business logic
└── static/         # Static files (uploads)
```
