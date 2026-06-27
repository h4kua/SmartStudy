"""
crew.py — CrewAI agent definitions for AI Academic Mentor.

Two crews:
  1. StudyPlanCrew   → 3 agents → produce a 7-day study schedule
  2. PerformanceReviewCrew → 2 agents → analyse quiz results + give tips
"""

import os

# Must be set before crewai import — otherwise CrewAI initialises
# the OpenTelemetry SDK and tries to push spans to a missing OTLP endpoint.
os.environ.setdefault("OTEL_SDK_DISABLED", "true")
os.environ.setdefault("OPENTELEMETRY_EXPORTER_OTLP_ENDPOINT", "")

import logging
from crewai import Agent, Task, Crew, LLM

logger = logging.getLogger(__name__)

# Cache a single LLM instance — recreating it per request is wasteful
_cached_llm: LLM | None = None


def _llm() -> LLM:
    """Return a cached Groq-powered LLM instance."""
    global _cached_llm
    if _cached_llm is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY not configured")
        _cached_llm = LLM(
            model="groq/llama-3.3-70b-versatile",
            api_key=api_key,
            temperature=0.7,
        )
    return _cached_llm


# ─────────────────────────────────────────────────────────────
# MARK: StudyPlanCrew
# ─────────────────────────────────────────────────────────────

class StudyPlanCrew:
    """
    Three-agent crew that produces a personalised 7-day study schedule.

    Agents
    ------
    1. Performance Analyst   — reads quiz history, finds patterns
    2. Learning Coach        — converts findings into actionable tips
    3. Study Scheduler       — builds the concrete weekly timetable
    """

    def run(
        self,
        subjects: list[str],
        quiz_history: list[dict],
        streak_days: int,
        total_study_minutes: int,
        study_goal: str,
    ) -> str:
        llm = _llm()

        # ── agents ──────────────────────────────────────────
        analyst = Agent(
            role="Academic Performance Analyst",
            goal=(
                "Analyse the student's quiz results to identify their "
                "top 3 strengths and top 3 knowledge gaps."
            ),
            backstory=(
                "You have 15 years of experience in learning analytics "
                "and educational data science. You excel at spotting "
                "patterns that help students improve quickly."
            ),
            llm=llm,
            verbose=False,
        )

        coach = Agent(
            role="Personalised Learning Coach",
            goal=(
                "Turn performance insights into 5 concrete, immediately "
                "actionable study recommendations."
            ),
            backstory=(
                "You are a master educator and motivational coach. "
                "Your recommendations are always specific, encouraging, "
                "and evidence-based — no vague advice."
            ),
            llm=llm,
            verbose=False,
        )

        scheduler = Agent(
            role="Study Schedule Optimizer",
            goal=(
                "Create a realistic, balanced 7-day study schedule "
                "using spaced repetition principles."
            ),
            backstory=(
                "You specialise in cognitive load theory and spaced "
                "repetition. You design schedules students actually "
                "follow — realistic session lengths, built-in breaks, "
                "and variety to prevent burnout."
            ),
            llm=llm,
            verbose=False,
        )

        # ── build context string ─────────────────────────────
        if quiz_history:
            rows = "\n".join(
                f"  • {q['subject']}: {q['score']}% "
                f"({q['difficulty']}) — topic: {q.get('topic', 'general')}"
                for q in quiz_history[-15:]
            )
        else:
            rows = "  (no quiz history yet)"

        context = (
            f"Student profile\n"
            f"  Subjects      : {', '.join(subjects) or 'none yet'}\n"
            f"  Study streak  : {streak_days} day(s)\n"
            f"  Total time    : {total_study_minutes} minutes\n"
            f"  Goal          : {study_goal}\n\n"
            f"Recent quiz results (latest first)\n"
            f"{rows}"
        )

        # ── tasks ────────────────────────────────────────────
        analyse_task = Task(
            description=(
                f"Analyse the following student profile and quiz data. "
                f"Identify top 3 strengths and top 3 weak areas.\n\n{context}"
            ),
            agent=analyst,
            expected_output=(
                "A structured analysis with four sections:\n"
                "1. Overall performance summary (2-3 sentences)\n"
                "2. Top 3 strengths (bullet list)\n"
                "3. Top 3 areas needing improvement (bullet list)\n"
                "4. Key insight (1 sentence)"
            ),
        )

        recommend_task = Task(
            description=(
                "Using the performance analysis above, produce 5 specific, "
                "numbered study recommendations the student can start today."
            ),
            agent=coach,
            expected_output=(
                "5 numbered recommendations. Each: title (bold), "
                "1–2 sentence explanation, and one concrete action step."
            ),
            context=[analyse_task],
        )

        schedule_task = Task(
            description=(
                f"Create a complete 7-day study schedule for: "
                f"{', '.join(subjects) or 'all subjects'}. "
                f"Each day: 2-3 Pomodoro sessions (25 min each). "
                f"Prioritise weaker subjects identified in the analysis. "
                f"Include short review sessions for strong subjects."
            ),
            agent=scheduler,
            expected_output=(
                "7-day schedule, one day per section.\n"
                "Format each day:\n"
                "  [Day Name]\n"
                "  • Session 1 — Subject: Topic (25 min)\n"
                "  • Session 2 — Subject: Topic (25 min)\n"
                "  • Session 3 — Subject: Topic (25 min)\n"
                "End with a 2-sentence motivational note."
            ),
            context=[analyse_task, recommend_task],
        )

        crew = Crew(
            agents=[analyst, coach, scheduler],
            tasks=[analyse_task, recommend_task, schedule_task],
            verbose=False,
        )

        result = crew.kickoff()
        return str(result)


# ─────────────────────────────────────────────────────────────
# MARK: DailyCoachCrew
# ─────────────────────────────────────────────────────────────

class DailyCoachCrew:
    """
    Single-agent crew that generates 3 daily study missions as structured JSON.
    Returns a JSON string with morning_message + actions array.
    """

    def run(
        self,
        subjects: list[str],
        quiz_history: list[dict],
        flashcard_decks: list[dict],
        exam_sessions: list[dict],
        notes: list[dict],
        streak_days: int,
        total_study_minutes: int,
    ) -> str:
        llm = _llm()

        # ── Build rich context ───────────────────────────────
        quiz_rows = "\n".join(
            f"  • {q['subject']}: {q['score']}% ({q['difficulty']}) — {q.get('topic', 'general')}"
            for q in quiz_history[-10:]
        ) or "  No quizzes yet"

        deck_rows = "\n".join(
            f"  • {d['title']}: {d.get('mastery_percent', 0):.0f}% mastered, {d.get('due_count', 0)} cards due"
            for d in flashcard_decks
        ) or "  No decks yet"

        exam_rows = "\n".join(
            f"  • {e['topic']}: {e.get('score', 0):.0f}% ({e.get('difficulty', 'intermediate')})"
            for e in exam_sessions[:5]
        ) or "  No exams yet"

        # Include actual note content previews so AI recommends real topics
        note_rows = "\n".join(
            f"  • \"{n['title']}\": {n.get('preview', '')[:200]}"
            for n in notes[:6]
        ) or "  No notes saved yet"

        context = (
            f"Subjects: {', '.join(subjects) or 'none'}\n"
            f"Streak: {streak_days} day(s)  |  Total study time: {total_study_minutes} min\n\n"
            f"Saved study notes (these are the student's actual learning materials):\n{note_rows}\n\n"
            f"Recent quizzes:\n{quiz_rows}\n\n"
            f"Flashcard decks:\n{deck_rows}\n\n"
            f"Recent exams:\n{exam_rows}"
        )

        coach = Agent(
            role="Daily Study Mission Planner",
            goal=(
                "Generate exactly 3 personalised daily study missions in valid JSON "
                "based on the student's performance data, targeting their weakest areas."
            ),
            backstory=(
                "You are an expert academic coach who creates engaging data-driven "
                "daily missions. You respond with a single valid JSON object only — "
                "no markdown, no backticks, no explanation before or after."
            ),
            llm=llm,
            verbose=False,
        )

        task = Task(
            description=(
                f"Analyse this student data and create 3 personalised study missions:\n\n"
                f"{context}\n\n"
                "CRITICAL RULES FOR TOPICS:\n"
                "- If the student has saved notes, use the EXACT note title as the topic for the quiz action.\n"
                "- The topic field must match real content the student has studied (note titles, deck titles, or subjects).\n"
                "- NEVER invent a topic that doesn't appear in the student data above.\n"
                "- If there are no notes/decks/quizzes yet, use one of the subject names.\n\n"
                "Respond with ONLY this JSON structure (no markdown, no extra text):\n"
                '{"morning_message":"Personalised 1-2 sentence greeting (mention streak if >0)",'
                '"actions":['
                '{"type":"quiz","title":"Quick Quiz","subject":"real subject name","topic":"EXACT note title or subject from above","question_count":5,"reason":"why in 1 sentence"},'
                '{"type":"flashcard","title":"Flashcard Sprint","subject":"real subject","topic":"EXACT deck title from above or subject name","card_count":8,"reason":"why in 1 sentence"},'
                '{"type":"exam","title":"Exam Prep","subject":"real subject","topic":"EXACT note title or subject from above","duration_min":15,"reason":"why in 1 sentence"}'
                ']}'
            ),
            agent=coach,
            expected_output=(
                "A single valid JSON object with morning_message (string) "
                "and actions (array of exactly 3 items). Topics must match actual content from student data."
            ),
        )

        crew = Crew(agents=[coach], tasks=[task], verbose=False)
        return str(crew.kickoff())


# ─────────────────────────────────────────────────────────────
# MARK: PerformanceReviewCrew
# ─────────────────────────────────────────────────────────────

class PerformanceReviewCrew:
    """
    Two-agent crew that reviews quiz performance and gives study tips.

    Agents
    ------
    1. Performance Analyst  — breaks down quiz scores by subject
    2. Learning Coach       — provides tips + motivation
    """

    def run(
        self,
        quiz_history: list[dict],
        subjects: list[str],
        streak_days: int,
    ) -> str:
        llm = _llm()

        analyst = Agent(
            role="Academic Performance Analyst",
            goal="Provide a clear, data-driven breakdown of quiz performance.",
            backstory=(
                "Expert in educational measurement and learning analytics. "
                "You turn raw scores into meaningful insights."
            ),
            llm=llm,
            verbose=False,
        )

        coach = Agent(
            role="Supportive Learning Coach",
            goal="Transform performance data into motivating, specific improvement strategies.",
            backstory=(
                "You specialise in growth mindset coaching. "
                "Your feedback is always honest, kind, and actionable."
            ),
            llm=llm,
            verbose=False,
        )

        # ── context ──────────────────────────────────────────
        if quiz_history:
            rows = "\n".join(
                f"  • {q['subject']}: {q['score']}% ({q['difficulty']})"
                for q in quiz_history
            )
            # BUG FIX: was integer division (//) — silently lost decimal precision (89.5 → 89)
            avg = round(sum(q["score"] for q in quiz_history) / len(quiz_history), 1)
            summary_line = f"  Average score: {avg}%   Quizzes taken: {len(quiz_history)}"
        else:
            rows = "  (no quiz history)"
            summary_line = "  No data yet."

        context = (
            f"Student quiz history\n{rows}\n\n"
            f"Summary stats\n{summary_line}\n"
            f"Subjects enrolled: {', '.join(subjects) or 'none'}\n"
            f"Study streak: {streak_days} day(s)"
        )

        # ── tasks ────────────────────────────────────────────
        review_task = Task(
            description=f"Review the following quiz performance data:\n\n{context}",
            agent=analyst,
            expected_output=(
                "A performance breakdown with:\n"
                "1. Overall average score\n"
                "2. Subject-by-subject analysis (strongest → weakest)\n"
                "3. Difficulty-level breakdown\n"
                "4. One key observation"
            ),
        )

        tips_task = Task(
            description=(
                "Based on the performance review, give 3 targeted study tips "
                "and a short motivational closing message."
            ),
            agent=coach,
            expected_output=(
                "3 numbered study tips (specific to the weak subjects identified), "
                "followed by a motivational paragraph (3-4 sentences)."
            ),
            context=[review_task],
        )

        crew = Crew(
            agents=[analyst, coach],
            tasks=[review_task, tips_task],
            verbose=False,
        )

        result = crew.kickoff()
        return str(result)
