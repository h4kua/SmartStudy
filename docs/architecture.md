# Architecture — AI Academic Mentor

## Overview

Single-target SwiftUI iOS app + Python FastAPI backend. The app never calls Groq directly — all LLM traffic goes through the local backend, which adds the API key. This keeps credentials off the device.

```
iPhone App (SwiftUI)
  │
  │  URLSession (localhost:8000 or 10.24.162.130:8000)
  ▼
crew_backend (FastAPI)
  │         │
  │         └── /groq/completions  ──► Groq API (api.groq.com)
  │                                       llama-3.3-70b-versatile
  └── /study/*  ──► CrewAI agents
                       DailyCoachCrew
                       StudyPlanCrew
                       PerformanceReviewCrew
```

---

## iOS Layer Structure

```
App/
  FinalProjectApp.swift          — @main, FirebaseApp.configure(), LearningStore injection
  MainTabView.swift              — 5-tab navigation

Features/<Name>/
  <Name>View.swift               — SwiftUI view, reads @StateObject or @ObservedObject VM
  <Name>ViewModel.swift          — @MainActor final class, @Published state, async funcs

Models/
  Models.swift                   — All Codable structs (QuizSession, FlashcardDeck, ...)

Services/
  GroqService.swift              — rawRequest() → POST /groq/completions; domain methods
  CrewAIService.swift            — BackendConfig + POST /study/* calls
  LearningStore.swift            — UserDefaults + JSON persistence, @Published arrays
  FirebaseAuthService.swift      — Firebase Email/Password auth
  NoteScannerService.swift       — VNRecognizeTextRequest on-device OCR
  HealthKitService.swift         — HKHealthStore queries (not surfaced in UI yet)
  NotificationService.swift      — UNUserNotificationCenter local push
  SpeechService.swift            — AVSpeechSynthesizer TTS
  ImagePickerView.swift          — UIViewControllerRepresentable for UIImagePickerController

Theme/
  StudyTheme.swift               — Colors, fonts (StudyFont), spacing (StudySpacing)
```

### MVVM rules

| Layer | Responsibility | Forbidden |
|---|---|---|
| View | Layout, animation, user input | Business logic, network calls |
| ViewModel | State, async tasks, error handling | UIKit, SwiftUI imports beyond `SwiftUI` |
| Service | Network, persistence, device APIs | `@Published`, SwiftUI |

---

## Backend Layer Structure

```
crew_backend/
  main.py        — FastAPI app, all endpoint handlers
  crew.py        — CrewAI agent + task definitions
  requirements.txt
  start.sh       — OTEL vars + uvicorn launcher
  .env           — GROQ_API_KEY (never commit)
```

### Endpoint map

| Method | Path | Handler | Notes |
|---|---|---|---|
| GET | `/health` | inline | Always `{"status": "ok"}` |
| POST | `/groq/completions` | `groq_completions` | Proxy: adds auth header, forwards to Groq |
| POST | `/study/daily-coach` | `daily_coach` | `DailyCoachCrew`, `raw_decode` JSON extraction |
| POST | `/study/weekly-plan` | `study_plan` | `StudyPlanCrew` |
| POST | `/study/performance-review` | `performance_review` | `PerformanceReviewCrew` |

### JSON extraction from LLM output

LLMs often append trailing text after the closing `}`. Always extract like this:

```python
brace_pos = raw.find('{')
if brace_pos == -1:
    raise ValueError("AI did not return a JSON object")
data, _ = json.JSONDecoder().raw_decode(raw, brace_pos)
```

Never use `re.search(r'\{.*\}', raw, re.DOTALL)` — greedy `.*` extends to the LAST `}` in the string.

---

## Key Design Decisions

### 1. Backend proxy for Groq API key

**Problem**: Embedding a secret API key in an Xcode scheme or app bundle is a leak risk.  
**Solution**: `POST /groq/completions` on the local FastAPI server. iOS sends the request body without credentials; the server adds `Authorization: Bearer $GROQ_API_KEY` from its `.env` file.  
**Tradeoff**: The backend must be running during development. The `BackendConfig` enum switches the URL between simulator (`localhost`) and physical device (static LAN IP).

### 2. Single `BackendConfig` source of truth

Defined at the top of `Services/CrewAIService.swift`:

```swift
enum BackendConfig {
    static let baseURL: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://10.24.162.130:8000"
        #endif
    }()
}
```

All services import and use `BackendConfig.baseURL`. The device IP is the only value to change when the Mac's network address changes.

### 3. OpenTelemetry disabled at shell level

CrewAI 0.80.0 registers an OTEL atexit hook that errors on `Ctrl+C`. Env vars must be exported in `start.sh` *before* Python starts — setting them inside Python (`os.environ.setdefault`) is too late for atexit hooks registered at import time.

### 4. Exam anti-cheat — `.background` only

iOS fires `scenePhase` changes `active → inactive → background` on every app switch. Listening on both `.inactive` and `.background` double-counts every exit. Only `.background` is used.

### 5. LearningStore — UserDefaults + JSON

All user data (`[QuizSession]`, `[FlashcardDeck]`, `[AnalyzedDocument]`, etc.) is encoded to JSON and stored in `UserDefaults`. This keeps the architecture simple (no Core Data schema migration risk) at the cost of no iCloud sync and a size ceiling (~1 MB practical limit for UserDefaults).

---

## Data Flow: Quiz Generation

```
QuizViewModel.generateQuiz()
  └─► GroqService.shared.generateQuiz(topic:difficulty:count:context:)
        └─► rawRequest(messages:) → POST /groq/completions (FastAPI)
              └─► Groq API → JSON with 'questions' array
        ← [QuizQuestion]
  └─► LearningStore.addQuizSession(session)
        └─► UserDefaults["quiz_sessions"] = JSON-encoded array
```

## Data Flow: Exam from Document

```
ExamSetupView (examSource == .document)
  └─► user selects AnalyzedDocument from store.analyzedDocuments
ExamSetupView taps "Start Exam"
  └─► vm.topic = doc.title
  └─► vm.documentContext = doc.originalText
  └─► vm.generateExam(store:)
        └─► GroqService.shared.generateQuiz(..., context: documentContext)
              system prompt includes: "Base questions ONLY on this content: …"
```

## Data Flow: Scan & Solve

```
SolveProblemSheet
  └─► user takes photo / picks from library
  └─► SolveProblemViewModel.scanAndSolve(image)
        ├─► NoteScannerService.recognizeText(from: image)   ← on-device Vision
        └─► GroqService.shared.solveProblem(detectedText)   ← via backend proxy
              temperature: 0.2, maxTokens: 1000
              response: Understanding / Solution / Answer / Key Concept
```
