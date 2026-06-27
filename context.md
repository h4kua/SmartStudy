# SmartStudy — Project Context

---

## Project Identity

| Field | Value |
|---|---|
| App Name | SmartStudy (AI Academic Mentor) |
| Bundle ID | `njjxzc.adu.cn.FinalProject` |
| GitHub | `https://github.com/h4kua/SmartStudy.git` |
| Course | iOS Application Development |
| Deadline | July 1, 2026 |
| Minimum Deployment Target | iOS 16.4 |
| Swift Version | 5.9 |
| Platform | iPhone only (SwiftUI, Single Target) |
| Developer | Juan |
| Architecture | MVVM + Service Layer |
| Primary AI Provider | Groq API (via local FastAPI proxy) |
| Language Model | llama-3.3-70b-versatile |
| Secondary AI | CrewAI multi-agent (Python FastAPI backend) |
| Persistence | UserDefaults + JSON encoding |
| Theme | Dark — "Midnight Aurora" |

---

## Practical Significance

The rapid growth of digital education has transformed how university students access learning resources. Although educational content is now more accessible than ever, students still encounter significant difficulties managing their learning process efficiently.

Many students experience challenges such as understanding difficult concepts, organizing study materials, preparing for examinations, maintaining consistent study habits, and receiving timely academic assistance. Traditional educational tools often solve only one aspect of the learning process. Note-taking applications focus on information storage, quiz applications focus on memorization, and AI chatbots provide explanations without maintaining academic context or tracking learning progress.

SmartStudy addresses this by providing an integrated educational ecosystem that combines artificial intelligence, real-time focus monitoring, document processing, knowledge assessment, multi-agent coaching, and learning analytics into a single mobile application.

---

## Problem Statement

**Problem 1: Information Overload** — Students receive large volumes of lecture slides, PDFs, and research papers weekly. Processing and organizing this manually requires substantial effort.

**Problem 2: Lack of Personalized Guidance** — Most educational platforms provide static content that does not adapt to individual needs. Students struggle to find explanations matched to their level.

**Problem 3: Ineffective Revision Techniques** — Many students rely on passive rereading. Active recall techniques (quizzes, flashcards) significantly improve retention.

**Problem 4: Poor Visibility Into Learning Progress** — Students rarely know if they are making sufficient progress. Without analytics, motivation decreases.

**Problem 5: No Accountability During Study** — Students lose focus easily when studying alone with no external monitoring or feedback.

---

## Core Features

### 1. AI Tutor (Tab: Tutor)

Real-time academic AI assistant using Groq's Llama 3.3 70B model.

- Concept explanation, homework assistance, math, programming
- Maintains conversation history (last 6 messages as context window)
- Injects active subject context into system prompt
- Suggestion chips for common question types
- Responses up to 1000 tokens; temperature 0.7

---

### 2. Smart Document Analyzer (Tab: Documents)

Students upload study material and receive AI-generated structured insights.

**Input methods:**
- Type or paste text directly
- Scan handwritten/printed notes with camera (Vision OCR)
- Import `.txt` or `.pdf` files via iOS file picker

**PDF import pipeline:**
1. PDFKit extracts text from internal character stream
2. Per-line reversed-text repair using tokenization-based word scoring (200+ word dictionary)
3. Warning card shown — user can verify extracted text
4. "Re-scan with Vision OCR" button for slide decks or complex layouts:
   - Renders each page at 1.5× scale to UIImage
   - Runs VNRecognizeTextRequest (.fast level) on each page
   - 4 pages processed concurrently via TaskGroup + GCD background threads
   - Produces correctly ordered text regardless of PDF internal structure

**Generated output:**
- Executive summary (3–5 sentences)
- Key concepts (bullet list)
- Important definitions (term → definition pairs)
- Topic categorization and suggested follow-up questions

**My Notes system:**
- Save analyzed documents as StudyNote
- Notes list with search, read-time estimate, tags
- Note detail view with Quiz/Flashcard generation
- Repair text function (re-runs reversed-line repair on saved notes)

---

### 3. AI Quiz Generator (Tab: Learn → Quizzes)

Converts topics or imported documents into multiple-choice assessments.

- Difficulty: Beginner / Intermediate / Advanced
- Question count: 5 / 10 / 15
- Per-question countdown timer (configurable)
- Haptic feedback on correct / wrong answers
- Full review mode with expandable answer cards and explanations
- Exam Mode: timed exam with anti-cheat detection (app-switch monitoring)

---

### 4. Flashcard Generator (Tab: Learn → Flashcards)

Extracts key concepts into review flashcards.

- Front (term/question) + Back (definition/answer) + Category + Difficulty
- 3D flip animation on tap
- Swipe right = knew it, swipe left = didn't know
- Mastery percentage per deck
- Quiz and study modes from saved notes

---

### 5. Focus Camera Session (Tab: Home → Start Focus)

Real-time attention monitoring using front camera + Vision framework.

- `AVCaptureSession` streams front camera frames
- `VNDetectFaceRectanglesRequest` detects face presence
- Tracks: total focus time, distraction events, focus percentage
- Voice coach feedback via `AVSpeechSynthesizer` ("Stay focused!", "Welcome back!")
- Voice coach toggleable during session
- Session summary on stop (duration, focus %, distraction count)
- `QuizFocusMonitor`: silent face-detection during quiz sessions (no preview shown)

---

### 6. Study Coach — Daily Coach (Tab: Home → Coach)

Multi-agent AI coaching powered by CrewAI backend.

**Modes:**
- **Daily Coach**: personalized today's study plan with action cards (subject, time, reason, icon)
- **Weekly Plan**: full 7-day study schedule
- **Performance Review**: AI analysis of quiz history with recommendations

**Daily Coach card fields:** `title`, `subject`, `estimatedTime`, `reason`, `type` (study/review/practice/rest), `iconName`, `actionColor`

Data cached in LearningStore with 1-hour staleness check. Dashboard shows mini action card preview (top 3 actions).

---

### 7. Pomodoro Study Timer (Tab: Learn → Timer)

- 25-min Focus → 5-min Short Break → 15-min Long Break cycle
- Animated circular progress ring
- 4-dot session indicator
- Push notification on session end

---

### 8. Learning Analytics (Tab: Progress)

- Total study sessions and minutes
- Quiz scores, trends, average score
- Flashcards reviewed
- Active study days and streak
- Weekly activity bar chart
- Subject performance breakdown
- HealthKit integration (step count, sleep hours)

---

## Navigation Architecture

### Tab Structure (5 tabs)

| # | Label | SF Symbol | Root View |
|---|---|---|---|
| 1 | Home | `house.fill` | `DashboardView` |
| 2 | Tutor | `brain.head.profile` | `AITutorView` |
| 3 | Documents | `doc.text.fill` | `DocumentAnalyzerView` |
| 4 | Learn | `lightbulb.fill` | `LearnHubView` |
| 5 | Progress | `chart.bar.fill` | `AnalyticsView` |

### LearnHubView

Top segmented picker switches between:
- `QuizView` → list of sessions + new quiz + Exam Mode
- `FlashcardsView` → list of decks + new deck
- `TimerView` → Pomodoro timer

---

## Module Structure (Actual File Tree)

```
FinalProject/
├── FinalProjectApp.swift          — @main, FirebaseApp.configure(), LearningStore injection
├── MainTabView.swift              — 5-tab navigation
│
├── Features/
│   ├── Dashboard/
│   │   └── DashboardView.swift    — Hero card, quick actions, Daily Coach widget, recent activity
│   ├── AITutor/
│   │   ├── AITutorView.swift
│   │   └── AITutorViewModel.swift
│   ├── DocumentAnalyzer/
│   │   ├── DocumentAnalyzerView.swift   — Input, file import warning, OCR button, results, Solve sheet
│   │   ├── DocumentAnalyzerViewModel.swift — PDF repair, Vision OCR, quiz/flashcard gen
│   │   └── StudyNotesListView.swift     — Notes list, NoteDetailView, NoteStudySheet
│   ├── Learn/
│   │   ├── LearnHubView.swift
│   │   ├── Quiz/
│   │   │   ├── QuizView.swift
│   │   │   ├── QuizSessionView.swift    — Per-question timer, haptics
│   │   │   ├── QuizViewModel.swift
│   │   │   ├── QuizReviewView.swift     — Expandable review cards
│   │   │   ├── ExamModeView.swift       — Timed exam, anti-cheat, debrief
│   │   │   └── ExamModeViewModel.swift
│   │   └── Flashcards/
│   │       ├── FlashcardsView.swift
│   │       ├── FlashcardReviewView.swift
│   │       └── FlashcardsViewModel.swift
│   ├── Timer/
│   │   ├── TimerView.swift
│   │   └── TimerViewModel.swift
│   ├── StudyCoach/
│   │   └── StudyCoachView.swift    — Daily Coach / Weekly Plan / Performance Review
│   ├── FocusCamera/
│   │   ├── FocusSessionView.swift
│   │   ├── FocusSessionViewModel.swift
│   │   ├── FocusCameraService.swift   — AVCaptureSession wrapper
│   │   ├── FocusAnalyzer.swift        — VNDetectFaceRectanglesRequest
│   │   ├── FocusVoiceCoach.swift      — AVSpeechSynthesizer voice feedback
│   │   └── QuizFocusMonitor.swift     — Silent face detection during quiz
│   ├── Analytics/
│   │   └── AnalyticsView.swift
│   ├── Auth/
│   │   └── AuthView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SubjectManagementView.swift
│
├── Models/
│   └── Models.swift               — All Codable structs
│
├── Services/
│   ├── GroqService.swift          — POST /groq/completions proxy calls
│   ├── CrewAIService.swift        — BackendConfig + POST /study/* calls
│   ├── LearningStore.swift        — @MainActor, UserDefaults + JSON, @Published arrays
│   ├── NoteScannerService.swift   — VNRecognizeTextRequest on-device OCR
│   ├── FirebaseAuthService.swift  — Firebase Email/Password auth
│   ├── HealthKitService.swift     — HKHealthStore queries
│   ├── NotificationService.swift  — UNUserNotificationCenter local push
│   ├── SpeechService.swift        — AVSpeechSynthesizer TTS
│   └── ImagePickerView.swift      — UIViewControllerRepresentable
│
└── Theme/
    └── StudyTheme.swift           — Colors, StudyFont, StudySpacing, components

crew_backend/
├── main.py             — FastAPI app, all endpoint handlers
├── crew.py             — CrewAI agent + task definitions
├── agents/
│   ├── coaching_agent.py
│   ├── health_agent.py
│   └── planner_agent.py
├── security.py         — Input sanitisation
├── requirements.txt
├── start.sh            — OTEL vars + uvicorn launcher
└── .env                — GROQ_API_KEY (never commit)
```

---

## Data Models

### Subject
```swift
struct Subject: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
}
```

### ChatMessage
```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let role: String        // "user" | "assistant"
    let content: String
    let date: Date
}
```

### QuizQuestion
```swift
struct QuizQuestion: Identifiable, Codable {
    var id: UUID
    var question: String
    var options: [String]       // exactly 4
    var correctIndex: Int       // 0–3
    var explanation: String
    var difficulty: Difficulty  // beginner | intermediate | advanced
}
```

### QuizSession
```swift
struct QuizSession: Identifiable, Codable {
    var id: UUID
    var title: String
    var subject: String?
    var difficulty: QuizQuestion.Difficulty
    var questions: [QuizQuestion]
    var userAnswers: [Int]          // -1 = unanswered
    var createdDate: Date
    var completedDate: Date?
    var score: Int                  // computed
    var percentage: Double          // computed
}
```

### ExamSession
```swift
struct ExamSession: Identifiable, Codable {
    var id: UUID
    var topic: String
    var timeLimitSeconds: Int
    var questions: [QuizQuestion]
    var userAnswers: [Int]
    var antiCheatWarnings: Int
    var startedDate: Date
    var completedDate: Date?
}
```

### Flashcard / FlashcardDeck
```swift
struct Flashcard: Identifiable, Codable {
    var id: UUID
    var front: String
    var back: String
    var category: String
    var difficulty: QuizQuestion.Difficulty
    var reviewCount: Int
    var knewItCount: Int
    var lastReviewed: Date?
}

struct FlashcardDeck: Identifiable, Codable {
    var id: UUID
    var title: String
    var subject: String?
    var cards: [Flashcard]
    var createdDate: Date
    var masteryPercent: Double   // computed
}
```

### AnalyzedDocument
```swift
struct AnalyzedDocument: Identifiable, Codable {
    var id: UUID
    var title: String
    var originalText: String
    var summary: String
    var keyConcepts: [String]
    var definitions: [String: String]
    var suggestedQuestions: [String]
    var subject: String?
    var analyzedDate: Date
}
```

### StudyNote
```swift
struct StudyNote: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var subject: String?
    var pageCount: Int
    var createdDate: Date
    var preview: String          // computed — first 120 chars
    var readTimeMinutes: Int     // computed — word count / 200 wpm
}
```

### DailyCoachAction
```swift
struct DailyCoachAction: Identifiable, Codable {
    var id: UUID
    var title: String
    var subject: String
    var estimatedTime: String
    var reason: String
    var type: String             // "study" | "review" | "practice" | "rest"
    var iconName: String
    var actionColor: Color       // computed from type
}
```

---

## LearningStore Architecture

`LearningStore` is the single source of truth — `@MainActor ObservableObject` injected via `.environmentObject()`.

```swift
@MainActor final class LearningStore: ObservableObject {
    @Published var subjects: [Subject]
    @Published var quizSessions: [QuizSession]
    @Published var flashcardDecks: [FlashcardDeck]
    @Published var analyzedDocuments: [AnalyzedDocument]
    @Published var studyNotes: [StudyNote]
    @Published var cachedDailyCoach: DailyCoachResponse?
    @Published var dailyCoachFetchedAt: Date?
    @Published var isDailyCoachStale: Bool          // computed — > 1 hour old

    // CRUD
    func addQuizSession(_ session: QuizSession)
    func updateQuizSession(_ session: QuizSession)
    func addFlashcardDeck(_ deck: FlashcardDeck)
    func updateFlashcardDeck(_ deck: FlashcardDeck)
    func deleteFlashcardDeck(id: UUID)
    func addAnalyzedDocument(_ doc: AnalyzedDocument)
    func addStudyNote(_ note: StudyNote)
    func deleteStudyNote(id: UUID)
    func cacheDailyCoach(_ response: DailyCoachResponse)
}
```

UserDefaults keys: `"mentor.subjects"`, `"mentor.quizSessions"`, `"mentor.flashcardDecks"`, `"mentor.analyzedDocuments"`, `"mentor.studyNotes"`, `"mentor.dailyCoach"`

---

## Service Architecture

### GroqService

All Groq calls go through the local FastAPI backend proxy — never directly to `api.groq.com`.

```swift
@MainActor final class GroqService {
    static let shared = GroqService()

    func rawRequest(messages: [[String:String]], ...) async throws -> String
    func analyzeDocument(title: String, text: String) async throws -> AnalyzedDocument
    func generateQuiz(topic: String, difficulty:..., count: Int, context: String?) async throws -> [QuizQuestion]
    func generateFlashcards(topic: String, count: Int) async throws -> [FlashcardDeck]
    func solveProblem(_ text: String) async throws -> String
    func generateExamDebrief(topic: String, score: Int, total: Int, ...) async throws -> String
}
```

### CrewAIService

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

@MainActor final class CrewAIService {
    static let shared = CrewAIService()

    func getDailyCoach(quizCount: Int, avgScore: Double, streak: Int, subjects: [String]) async throws -> DailyCoachResponse
    func getWeeklyPlan(subjects: [String], hoursPerDay: Double, goals: String) async throws -> String
    func getPerformanceReview(sessions: [QuizSession]) async throws -> String
}
```

### NoteScannerService

On-device Vision OCR — no network, no data leaves device.

```swift
final class NoteScannerService {
    static func recognizeText(from image: UIImage) async throws -> String
    // VNRecognizeTextRequest .accurate, en-US + id-ID, sorted top→bottom L→R
}
```

Used by:
- `DocumentAnalyzerViewModel.scanImage()` — scan notes photo
- `SolveProblemViewModel.scanAndSolve()` — Scan & Solve feature

PDF page OCR uses an inline `ocrPageFast()` method (`.fast` level, GCD background dispatch, 4 pages concurrent).

---

## Backend Architecture (crew_backend)

### Endpoint Map

| Method | Path | Handler | Notes |
|---|---|---|---|
| GET | `/health` | inline | Always `{"status": "ok"}` |
| POST | `/groq/completions` | `groq_completions` | Proxy: adds auth header, forwards to Groq |
| POST | `/study/daily-coach` | `daily_coach` | `DailyCoachCrew` — returns action list |
| POST | `/study/weekly-plan` | `study_plan` | `StudyPlanCrew` |
| POST | `/study/performance-review` | `performance_review` | `PerformanceReviewCrew` |

### Key Design Decisions

**1. Backend proxy for Groq API key** — iOS never calls `api.groq.com` directly. All LLM traffic goes through `POST /groq/completions` on the local FastAPI server. The server adds `Authorization: Bearer $GROQ_API_KEY` from `.env`. Keeps credentials off the device.

**2. Single BackendConfig source of truth** — `BackendConfig.baseURL` in `CrewAIService.swift` switches between `localhost:8000` (simulator) and `10.24.162.130:8000` (device). The only value to change when the Mac's network address changes.

**3. OpenTelemetry disabled at shell level** — CrewAI 0.80.0 registers an OTEL atexit hook that errors on `Ctrl+C`. Env vars `OTEL_SDK_DISABLED=true` and `OPENTELEMETRY_EXPORTER_OTLP_ENDPOINT=""` must be set in `start.sh` before Python starts — setting them inside Python is too late for atexit hooks registered at import time.

**4. JSON extraction from LLM output** — Always use:
```python
brace_pos = raw.find('{')
data, _ = json.JSONDecoder().raw_decode(raw, brace_pos)
```
Never use `re.search(r'\{.*\}', raw, re.DOTALL)` — greedy `.*` extends to the last `}`.

### Start Backend
```bash
cd crew_backend
./start.sh
# or:
source .venv/bin/activate && uvicorn main:app --reload --port 8000
```

---

## Theme System (StudyTheme)

File: `Theme/StudyTheme.swift`

### Colors
```swift
enum StudyTheme {
    static let background        // dark midnight
    static let surface           // slightly lighter card surface
    static let surface2          // input field background
    static let accent            // #6699FF blue
    static let accentSoft        // accent.opacity(0.12)
    static let success           // #38D17A green
    static let warning           // #FFC838 amber
    static let danger            // #FF6161 red
    static let primaryText       // white
    static let secondaryText     // gray 54%
    static let tertiaryText      // gray 33%
    static let surfaceStroke     // white 7%
    static let backgroundGradient // LinearGradient
    static let shortBreakColor   // teal
    static let longBreakColor    // purple
}
```

### Typography (StudyFont)
```swift
enum StudyFont {
    static let hero       // largeTitle, rounded, black
    static let cardTitle  // title3, rounded, semibold
    static let subtitle   // subheadline, rounded, semibold
    static let body       // body, rounded
    static let caption    // caption, rounded
    static let tiny       // caption2, rounded, medium
}
```

### Spacing (StudySpacing)
```swift
enum StudySpacing {
    static let xSmall:  CGFloat = 4
    static let small:   CGFloat = 8
    static let medium:  CGFloat = 16
    static let large:   CGFloat = 24
    static let xLarge:  CGFloat = 32
    static let xxLarge: CGFloat = 52
}
```

### Reusable Components
- `StudyCard<Content>` — dark surface card with border
- `PrimaryStudyButtonStyle` — gradient fill, press scale animation
- `GhostStudyButtonStyle` — outline border, accent tint

**Rule**: All UI must use `StudyTheme.*`, `StudyFont.*`, `StudySpacing.*`. No raw color literals, no raw numeric spacing.

---

## MVVM Rules

| Layer | Responsibility | Forbidden |
|---|---|---|
| View | Layout, animation, user input | Business logic, network calls |
| ViewModel | `@MainActor final class`, `@Published` state, `async` funcs | UIKit, direct network calls |
| Service | Network, persistence, device APIs | `@Published`, SwiftUI |

No `DispatchQueue.main.async` in ViewModels — use `@MainActor` isolation.

---

## Security Rules (BLOCKER before every commit)

- `GROQ_API_KEY` value in `.xcscheme` must be `""` (empty)
- `crew_backend/.env` must never be staged
- `GoogleService-Info.plist` must never be committed
- No `gsk_` key literals in any Swift or Python file

Quick check:
```bash
git diff --cached --name-only | grep -E "\.env|GoogleService"
grep -r "gsk_" --include="*.swift" FinalProject/
```

---

## Environment Setup

### Prerequisites
- Xcode 15+
- iOS 16.4 simulator or physical iPhone
- Python 3.11+ with pip
- A Groq API key from `console.groq.com`

### iOS App
1. Open `FinalProject.xcodeproj` in Xcode
2. Set `GROQ_API_KEY = ""` in Run scheme environment variables (app reads via backend proxy)
3. Press ⌘R — backend must be running for AI features

### Python Backend
```bash
cd crew_backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # add your GROQ_API_KEY
./start.sh
```

### BackendConfig — change device IP
In `Services/CrewAIService.swift`, update the `#else` branch:
```swift
return "http://<YOUR_MAC_LOCAL_IP>:8000"
```

---

## AI Agent Architecture

### Development Agents (Claude Code)

The application was built using Claude Code (Anthropic Claude Sonnet 4.6) operating as an AI software development agent with three specialized roles:

**Architect Agent** — system design, context.md authoring, data model specification, build order.

**Coder Agent** — full Swift/SwiftUI implementation, `project.pbxproj` management, Python backend endpoints, async/await networking.

**Review & Debug Agent** — `xcodebuild` verification after each step, compiler error diagnosis, iterative bug fixing.

The agents operated sequentially. `context.md` served as shared memory across all agent transitions.

---

### In-App AI Agents (Groq / Llama 3.3)

Five distinct AI agents defined by different system prompts, all sharing the same Groq endpoint:

#### Agent A — Tutor Agent
Activated: user sends message in AI Tutor tab.
System role: encouraging academic tutor. Maintains last 6 messages as context.
Output: free-form markdown text.

#### Agent B — Document Analysis Agent
Activated: "Analyze Document" in Documents tab.
System role: expert academic document analyzer.
Output: strict JSON `{ summary, keyConcepts[], definitions{}, suggestedQuestions[], subject }`.

#### Agent C — Quiz Generation Agent
Activated: "Generate Quiz" or post-document analysis.
System role: expert quiz creator.
Output: JSON array `[{ question, options[4], correctIndex, explanation, difficulty }]`.

#### Agent D — Flashcard Generation Agent
Activated: "Generate Flashcards".
System role: active-recall content creator.
Output: JSON array `[{ front, back, category, difficulty }]`.

#### Agent E — Exam Debrief Agent
Activated: after exam submission in Exam Mode.
System role: academic performance coach.
Output: free-form markdown debrief with strengths, weaknesses, recommendations.

---

### Multi-Agent Backend (CrewAI)

Three CrewAI crews run in the Python backend:

**DailyCoachCrew** (`POST /study/daily-coach`) — coaching_agent + health_agent → personalized today's action plan.

**StudyPlanCrew** (`POST /study/weekly-plan`) — planner_agent → 7-day schedule.

**PerformanceReviewCrew** (`POST /study/performance-review`) — coaching_agent → analysis of quiz history with recommendations.

---

## Testing

### Build Verification
`xcodebuild -scheme FinalProject -destination 'platform=iOS Simulator,name=iPhone 16' build`

Expected: `** BUILD SUCCEEDED **` with no new errors.

### Functional Test Cases

| # | Feature | Test Case | Status |
|---|---|---|---|
| TC-01 | Build | All modules compile clean | ✅ Pass |
| TC-02 | AI Tutor | Send message → response shown | ✅ Pass |
| TC-03 | AI Tutor | Empty input → send button disabled | ✅ Pass |
| TC-04 | Document Analyzer | Paste text → Analyze → summary shown | ✅ Pass |
| TC-05 | Document Analyzer | PDF import → warning card shown | ✅ Pass |
| TC-06 | Document Analyzer | "Re-scan with OCR" → replaces text | ✅ Pass |
| TC-07 | Document Analyzer | Reversed PDF lines → repaired automatically | ✅ Pass |
| TC-08 | Quiz | Generate quiz → answer → score shown | ✅ Pass |
| TC-09 | Quiz | Wrong answer → red highlight + explanation | ✅ Pass |
| TC-10 | Quiz | Per-question timer counts down | ✅ Pass |
| TC-11 | Exam Mode | Anti-cheat fires on app backgrounding | ✅ Pass |
| TC-12 | Exam Mode | AI debrief loads after submit | ✅ Pass |
| TC-13 | Flashcards | Generate deck → flip card → know/don't know | ✅ Pass |
| TC-14 | Flashcards | Mastery percentage updates | ✅ Pass |
| TC-15 | Focus Camera | Face detected → focus % tracked | ✅ Pass |
| TC-16 | Focus Camera | Voice coach fires on distraction | ✅ Pass |
| TC-17 | Study Coach | Daily Coach loads action cards | ✅ Pass |
| TC-18 | Study Coach | Dashboard shows top 3 actions | ✅ Pass |
| TC-19 | Notes | Save as Note → appears in list | ✅ Pass |
| TC-20 | Analytics | Quiz completion → chart updates | ✅ Pass |
| TC-21 | Persistence | Kill + relaunch → all data restored | ✅ Pass |
| TC-22 | Backend | POST /groq/completions proxies correctly | ✅ Pass |
| TC-23 | Backend | POST /study/daily-coach returns actions | ✅ Pass |

---

## Commit History

All commits use format: `<type>: <short description>`

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

See `git log --oneline` for full history.
