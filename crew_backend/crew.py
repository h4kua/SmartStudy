"""
crew.py — CrewAI agent definitions for AI Academic Mentor.

Two crews:
  1. StudyPlanCrew   → 3 agents → produce a 7-day study schedule
  2. PerformanceReviewCrew → 2 agents → analyse quiz results + give tips
"""

import os
from crewai import Agent, Task, Crew, LLM


def _llm() -> LLM:
    """Create a Groq-powered LLM instance."""
    return LLM(
        model="groq/llama-3.3-70b-versatile",
        api_key=os.getenv("GROQ_API_KEY"),
        temperature=0.7,
    )


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
            avg = sum(q["score"] for q in quiz_history) // len(quiz_history)
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
