# AGENTS.md — AI Academic Mentor

Agent instructions for Claude Code and any automated tooling working on this repository.

---

## Project Snapshot

| Field | Value |
|---|---|
| App | AI Academic Mentor (iOS) |
| Bundle ID | `njjxzc.adu.cn.FinalProject` |
| Xcode scheme | `FinalProject` |
| iOS target | 16.4+ |
| Architecture | MVVM + Service Layer |
| AI provider | Groq (`llama-3.3-70b-versatile`) via backend proxy |
| Backend | Python FastAPI + CrewAI (`crew_backend/`) |
| Persistence | UserDefaults + JSON encoding (`LearningStore`) |
| Theme | Dark "Midnight" (`StudyTheme`, `StudyFont`, `StudySpacing`) |

---

## Repository Layout

```
FinalProject/               ← Xcode project root
  FinalProject/
    App/                    ← Entry point, theme, tab structure
    Features/               ← One folder per UI feature
      AITutor/
      Analytics/
      Auth/
      Dashboard/
      DocumentAnalyzer/     ← Scan & Solve also lives here
      FocusCamera/          ← QuizFocusMonitor + FocusCameraService
      Learn/
        Quiz/               ← QuizViewModel, ExamModeViewModel, ReviewView
        Flashcards/
      Settings/
      StudyCoach/           ← CrewAI daily missions
      Timer/
    Models/                 ← Models.swift (all data types)
    Services/               ← GroqService, CrewAIService, LearningStore, etc.
    Theme/                  ← StudyTheme.swift
  crew_backend/             ← Python FastAPI backend
    main.py                 ← All endpoints
    crew.py                 ← CrewAI agent definitions
    requirements.txt
    start.sh                ← Dev server launcher
    .env                    ← GROQ_API_KEY (never commit)
  docs/                     ← Architecture, features, checklists
  scripts/                  ← init.sh, test.sh
```

---

## Build & Run

### iOS

```bash
# Build (simulator)
xcodebuild -scheme FinalProject \
  -project FinalProject.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Run tests
xcodebuild -scheme FinalProject \
  -project FinalProject.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

### Backend

```bash
cd crew_backend
./start.sh          # installs deps, sets OTEL vars, launches on :8000
```

Quick smoke test after the server starts:

```bash
curl http://localhost:8000/health
```

### Full environment setup

```bash
./scripts/init.sh   # checks Xcode, Python, creates venv, validates .env
./scripts/test.sh   # build iOS + backend health check
```

---

## Coding Conventions

- **Theme only** — use `StudyTheme`, `StudyFont`, `StudySpacing`, `StudyRadius`. No raw colors or font sizes.
- **Async networking** — all Groq/backend calls go through `GroqService.shared` or `CrewAIService.shared`. Never call `api.groq.com` directly from a view or ViewModel.
- **@MainActor** — all ViewModels are `@MainActor final class`. Service singletons are `@MainActor` where they publish state.
- **New Swift files** must be registered in `FinalProject.xcodeproj` (Xcode does this automatically when you add via the IDE; adding via filesystem alone causes build failures).
- **New feature directories** under `Features/` follow the pattern: `FeatureNameView.swift` + `FeatureNameViewModel.swift` in the same folder.
- **No comments** unless the WHY is non-obvious (hidden invariant, workaround, subtle constraint).

---

## Security Rules — NEVER violate

| Rule | Reason |
|---|---|
| `GROQ_API_KEY` must be empty (`value = ""`) in `.xcscheme` before any commit/push | Prevents secret leakage in shared scheme |
| `.env` must never be committed | Contains live API key |
| `GoogleService-Info.plist` must never be committed | Contains Firebase credentials |
| Do not add `--no-verify` to git commands | Bypasses pre-commit hooks |

The `.gitignore` already excludes these files. Verify with `git status` before committing.

---

## Key Invariants

- **Backend proxy pattern**: All iOS → Groq calls go through `POST /groq/completions` on the local backend. The `GROQ_API_KEY` lives only in `crew_backend/.env`.
- **Backend URL**: Defined once in `BackendConfig.baseURL` (in `CrewAIService.swift`). Update the physical-device IP there.
- **OpenTelemetry**: Disabled via shell exports in `start.sh` before Python starts. The `os.environ.setdefault` calls in `main.py`/`crew.py` are a secondary guard for direct `uvicorn` invocations.
- **JSON from LLM**: Always use `json.JSONDecoder().raw_decode(raw, raw.find('{'))` — never a greedy `\{.*\}` regex.
- **Numeric fields from LLM**: Use the `flexInt` helper in `DailyCoachAction` — LLMs return `"5"` (string) or `5` (int) unpredictably.
- **Exam anti-cheat**: `ExamSessionView` fires `logAntiCheatWarning` on `scenePhase == .background` only (not `.inactive`) to avoid double-counting the transition.

---

## What Agents Should NOT Do

- Do not write or guess API keys, credentials, or tokens in any file.
- Do not push to remote without explicit user confirmation.
- Do not add new files to `FinalProject/` via filesystem without updating `project.pbxproj`.
- Do not remove `interactiveDismissDisabled(true)` from `ExamSessionView` — it enforces exam lockdown.
- Do not change the `QuizFocusMonitor` camera behavior — it intentionally runs without a visible preview.
- Do not mock `LearningStore` in tests — use a fresh in-memory instance to avoid fixture drift.

---

## Feature Status

See `docs/features.json` for machine-readable status and `docs/progress.md` for a narrative summary.
