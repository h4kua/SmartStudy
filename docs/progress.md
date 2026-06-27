# Progress — AI Academic Mentor

Deadline: **July 1, 2026**
Last updated: 2026-06-27

---

## Feature Status

| Feature | Status | Notes |
|---|---|---|
| AI Tutor chat | Done | Groq proxy, 6-message context window |
| Document Analyzer | Done | Text + PDF + camera scan |
| Scan & Solve | Done | Vision OCR → AI step-by-step solution |
| Quiz Generator | Done | Focus monitor, per-question timer, review screen |
| Exam Mode | Done | Anti-cheat, timed, from topic or document |
| Flashcard Generator | Done | Swipe review |
| AI Study Coach | Done | CrewAI daily missions, cached per day |
| Analytics Dashboard | Done | Score trends, streak, weekly chart |
| Home Dashboard | Done | Today's Mission widget, quick-action cards |
| Authentication | Done | Firebase Email/Password |

---

## Backend Endpoints

| Endpoint | Status | Notes |
|---|---|---|
| `GET /health` | Done | Always returns `{"status": "ok"}` |
| `POST /groq/completions` | Done | Proxy — adds `GROQ_API_KEY`, forwards to Groq |
| `POST /study/daily-coach` | Done | CrewAI `DailyCoachCrew` |
| `POST /study/weekly-plan` | Done | CrewAI `StudyPlanCrew` |
| `POST /study/performance-review` | Done | CrewAI `PerformanceReviewCrew` |

---

## Security Checklist

- [x] `GROQ_API_KEY` is empty in `.xcscheme`
- [x] `crew_backend/.env` is in `.gitignore`
- [x] `GoogleService-Info.plist` is in `.gitignore`
- [x] No direct Groq calls from iOS — all go through `/groq/completions` proxy
- [x] OpenTelemetry disabled in `start.sh` (avoids noisy Ctrl+C atexit error)

---

## Known Limitations

- Backend requires local Wi-Fi — physical device and Mac must be on the same network.
- `BackendConfig` device IP is hardcoded to `10.24.162.130`. Update if the Mac's IP changes.
- `LearningStore` uses `UserDefaults` — data is per-device, not synced across devices.
- `HealthKit` integration is present (`HealthKitService`) but not surfaced in the current UI.

---

## Recently Completed

- **2026-06-27** — Exam Mode: "From Document" source toggle + document picker UI  
- **2026-06-27** — QuizReviewView: redesigned summary card (large score, grade, difficulty badge)  
- **2026-06-27** — Scan & Solve: enlarged Take Photo button (120pt card with big camera icon)  
- **2026-06-27** — CrewAI JSON extraction: replaced greedy regex with `raw_decode` to fix trailing-brace parse failures  
- **2026-06-27** — Exam anti-cheat: fire only on `scenePhase == .background` (not `.inactive`) to prevent double-counting  
- **2026-06-27** — All Groq calls moved to backend proxy — `GROQ_API_KEY` removed from Xcode scheme  
