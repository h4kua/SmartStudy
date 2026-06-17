"""
main.py — FastAPI entry point for the AI Academic Mentor CrewAI backend.

Endpoints
---------
GET  /health                   → server status check
POST /study/weekly-plan        → generate a personalised 7-day study schedule
POST /study/performance-review → analyse quiz history and give study tips

Start the server
----------------
  cd crew_backend
  ./start.sh
  # or manually:
  source .venv/bin/activate
  uvicorn main:app --reload --port 8000
"""

import os
import time
import logging
from dotenv import load_dotenv

# Load .env before importing crew (crew reads GROQ_API_KEY at import time)
load_dotenv()

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional

from crew import StudyPlanCrew, PerformanceReviewCrew

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# App setup
# ─────────────────────────────────────────────────────────────

app = FastAPI(
    title="AI Academic Mentor — CrewAI Backend",
    description="Multi-agent study planning and performance review powered by CrewAI + Groq",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # iOS simulator / local only
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware — logs method, path, and duration
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    logger.info(f"{request.method} {request.url.path} → {response.status_code} ({duration:.1f}s)")
    return response


@app.on_event("startup")
async def startup_check():
    """Validate config on startup so errors surface immediately."""
    if not os.getenv("GROQ_API_KEY"):
        logger.warning("⚠️  GROQ_API_KEY not set — AI endpoints will fail. Add it to .env")
    else:
        logger.info("✅ GROQ_API_KEY configured")


# ─────────────────────────────────────────────────────────────
# Request / Response models
# ─────────────────────────────────────────────────────────────

class QuizHistoryItem(BaseModel):
    subject: str
    score: int = Field(ge=0, le=100, description="Percentage score 0–100")
    difficulty: str = Field(default="intermediate")
    topic: str = Field(default="")


class WeeklyPlanRequest(BaseModel):
    subjects: list[str] = Field(default_factory=list)
    quiz_history: list[QuizHistoryItem] = Field(default_factory=list)
    streak_days: int = Field(default=0, ge=0)
    total_study_minutes: int = Field(default=0, ge=0)
    study_goal: str = Field(default="Improve academic performance")


class PerformanceReviewRequest(BaseModel):
    quiz_history: list[QuizHistoryItem]
    subjects: list[str] = Field(default_factory=list)
    streak_days: int = Field(default=0, ge=0)


class PlanResponse(BaseModel):
    success: bool
    plan: str


class ReviewResponse(BaseModel):
    success: bool
    review: str


# ─────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Quick liveness check used by the iOS app."""
    key_ok = bool(os.getenv("GROQ_API_KEY"))
    return {
        "status": "ok",
        "version": "1.0.0",
        "groq_key_configured": key_ok,
    }


@app.post("/study/weekly-plan", response_model=PlanResponse)
async def get_weekly_plan(req: WeeklyPlanRequest) -> PlanResponse:
    """
    Run the 3-agent StudyPlanCrew and return a personalised weekly schedule.
    Typical latency: 20–45 seconds (3 LLM calls in sequence).
    """
    if not os.getenv("GROQ_API_KEY"):
        raise HTTPException(
            status_code=500,
            detail="GROQ_API_KEY not set in crew_backend/.env",
        )
    try:
        crew = StudyPlanCrew()
        result = crew.run(
            subjects=req.subjects,
            quiz_history=[q.model_dump() for q in req.quiz_history],
            streak_days=req.streak_days,
            total_study_minutes=req.total_study_minutes,
            study_goal=req.study_goal,
        )
        return PlanResponse(success=True, plan=result)
    except Exception as exc:
        # BUG FIX: don't expose internal stack traces to client
        print(f"[weekly-plan] Error: {exc}")
        raise HTTPException(status_code=500, detail="Failed to generate study plan. Check server logs.")


@app.post("/study/performance-review", response_model=ReviewResponse)
async def get_performance_review(req: PerformanceReviewRequest) -> ReviewResponse:
    """
    Run the 2-agent PerformanceReviewCrew and return a score analysis + tips.
    Typical latency: 15–30 seconds (2 LLM calls in sequence).
    """
    if not os.getenv("GROQ_API_KEY"):
        raise HTTPException(
            status_code=500,
            detail="GROQ_API_KEY not set in crew_backend/.env",
        )
    try:
        crew = PerformanceReviewCrew()
        result = crew.run(
            quiz_history=[q.model_dump() for q in req.quiz_history],
            subjects=req.subjects,
            streak_days=req.streak_days,
        )
        return ReviewResponse(success=True, review=result)
    except Exception as exc:
        # BUG FIX: don't expose internal stack traces to client
        print(f"[performance-review] Error: {exc}")
        raise HTTPException(status_code=500, detail="Failed to generate performance review. Check server logs.")
