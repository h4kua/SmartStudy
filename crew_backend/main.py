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

# Disable OpenTelemetry tracing before any CrewAI/LiteLLM import.
# Without this, CrewAI tries to push spans to a non-existent OTLP collector
# and prints a noisy timeout error after every request.
os.environ.setdefault("OTEL_SDK_DISABLED", "true")
os.environ.setdefault("OPENTELEMETRY_EXPORTER_OTLP_ENDPOINT", "")

import json
import time
import logging
import httpx
from dotenv import load_dotenv

# Load .env before importing crew (crew reads GROQ_API_KEY at import time)
load_dotenv()

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from crew import StudyPlanCrew, PerformanceReviewCrew, DailyCoachCrew

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


class FlashcardDeckItem(BaseModel):
    title: str
    mastery_percent: float = 0.0
    due_count: int = 0
    total_cards: int = 0


class ExamItem(BaseModel):
    topic: str
    score: float = 0.0
    difficulty: str = "intermediate"


class NotePreview(BaseModel):
    title: str
    preview: str = ""    # first ~300 chars of the note content


class DailyCoachRequest(BaseModel):
    subjects: list[str] = Field(default_factory=list)
    quiz_history: list[QuizHistoryItem] = Field(default_factory=list)
    flashcard_decks: list[FlashcardDeckItem] = Field(default_factory=list)
    exam_sessions: list[ExamItem] = Field(default_factory=list)
    notes: list[NotePreview] = Field(default_factory=list)
    streak_days: int = Field(default=0, ge=0)
    total_study_minutes: int = Field(default=0, ge=0)


class GroqProxyRequest(BaseModel):
    """Proxy body: same fields GroqService sends, API key added server-side."""
    model: str = "llama-3.3-70b-versatile"
    messages: list[dict]
    max_tokens: int = Field(default=400, ge=1, le=8192)
    temperature: float = Field(default=0.75, ge=0.0, le=2.0)


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


@app.post("/study/daily-coach")
async def daily_coach(req: DailyCoachRequest) -> dict:
    """
    Run DailyCoachCrew and return 3 structured daily study missions.
    Returns JSON with morning_message + actions array.
    Typical latency: 15–25 seconds (single LLM call).
    """
    if not os.getenv("GROQ_API_KEY"):
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not set in crew_backend/.env")
    try:
        crew = DailyCoachCrew()
        raw = crew.run(
            subjects=req.subjects,
            quiz_history=[q.model_dump() for q in req.quiz_history],
            flashcard_decks=[d.model_dump() for d in req.flashcard_decks],
            exam_sessions=[e.model_dump() for e in req.exam_sessions],
            notes=[n.model_dump() for n in req.notes],
            streak_days=req.streak_days,
            total_study_minutes=req.total_study_minutes,
        )
        # Find the first '{' and parse from there.
        # raw_decode stops at the correct closing brace even if the LLM
        # adds trailing text (e.g. "Final Answer: {...} Task done."),
        # unlike a greedy regex which extends to the last '}' in the string.
        brace_pos = raw.find('{')
        if brace_pos == -1:
            raise ValueError("AI did not return a JSON object")
        data, _ = json.JSONDecoder().raw_decode(raw, brace_pos)
        return {"success": True, **data}
    except json.JSONDecodeError as e:
        logger.error("daily_coach JSON parse error: %s", e)
        raise HTTPException(status_code=500, detail="AI returned malformed JSON. Please retry.")
    except Exception as exc:
        logger.error("daily_coach error: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to generate daily coach plan. Check server logs.")


@app.post("/groq/completions")
async def groq_completions(req: GroqProxyRequest) -> dict:
    """
    Proxy for all iOS Groq calls (quiz, flashcards, chat, doc analysis, exam debrief).
    The API key lives only in crew_backend/.env — not in the Xcode scheme.
    Works on physical devices, not just the simulator.
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not set in crew_backend/.env")

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                json={
                    "model":       req.model,
                    "messages":    req.messages,
                    "max_tokens":  req.max_tokens,
                    "temperature": req.temperature,
                },
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type":  "application/json",
                },
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Groq request timed out")
    except httpx.RequestError as exc:
        raise HTTPException(status_code=502, detail=f"Cannot reach Groq: {exc}")

    if resp.status_code != 200:
        logger.error("Groq proxy error %s: %s", resp.status_code, resp.text[:300])
        raise HTTPException(
            status_code=resp.status_code,
            detail=f"Groq returned {resp.status_code}: {resp.text[:200]}"
        )

    return resp.json()
