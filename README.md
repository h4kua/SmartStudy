# SmartStudy — AI Academic Mentor

> An intelligent iOS study companion powered by Groq (Llama 3.3 70B), CrewAI multi-agent backend, and on-device Vision OCR. Built with SwiftUI, MVVM, and real-time focus monitoring.

---

## Features

### AI Tutor
- Real-time academic chat powered by Groq Llama 3.3 70B
- Concept explanation, homework help, math, and programming assistance
- Maintains conversation context (last 6 messages)
- Subject-aware system prompt injection
- Suggestion chips for quick questions

### Smart Document Analyzer
- Import PDF files, `.txt` files, or scan printed/handwritten notes with camera
- AI-generated summary, key concepts, definitions, and suggested study questions
- Automatic reversed-text repair for RTL PDFs (tokenization-based word scoring)
- **Vision OCR fallback** for complex slide decks: renders each page to image and runs VNRecognizeTextRequest — produces correct reading order regardless of PDF internal structure
- 4 pages processed concurrently for fast scanning
- Save analyzed content as Study Notes with quiz/flashcard generation

### AI Quiz Generator
- Multiple-choice quizzes from any topic or imported document
- Difficulty: Beginner / Intermediate / Advanced
- Question count: 5 / 10 / 15 with per-question countdown timer
- Haptic feedback, full review mode with explanations
- **Exam Mode**: timed exam with anti-cheat detection (monitors app switching)
- AI debrief after exam submission

### Flashcard System
- AI-generated decks from any topic
- 3D flip animation, swipe-to-review (knew it / didn't know)
- Mastery percentage per deck

### Focus Camera Session
- Real-time attention monitoring using front camera + Vision face detection
- Tracks focus time, distraction events, and focus percentage
- Voice coach feedback (toggleable): "Stay focused!", "Welcome back!"
- Session summary on completion

### Daily Coach (Multi-Agent AI)
- **Daily Coach**: personalized today's action plan — study tasks with subject, time estimate, and reason
- **Weekly Plan**: full 7-day study schedule
- **Performance Review**: AI analysis of quiz history with improvement tips
- Powered by CrewAI multi-agent backend (Python FastAPI)
- Dashboard shows today's top 3 actions at a glance

### Pomodoro Timer
- 25-min Focus → 5-min Short Break → 15-min Long Break
- Animated circular progress ring
- Push notification on session end

### Learning Analytics
- Weekly activity bar chart
- Quiz score trends and streak tracking
- Flashcard mastery overview
- HealthKit integration (step count, sleep hours)

---

## Architecture

```
SmartStudy/
├── FinalProjectApp.swift          — @main, Firebase configure, LearningStore injection
├── MainTabView.swift              — 5-tab navigation
│
├── Features/
│   ├── Dashboard/                 — Hero, quick actions, Daily Coach widget
│   ├── AITutor/                   — Chat UI + ViewModel
│   ├── DocumentAnalyzer/          — PDF import, Vision OCR, notes, Scan & Solve
│   ├── Learn/
│   │   ├── Quiz/                  — Quiz, ExamMode, Review
│   │   └── Flashcards/            — Deck list, flip review
│   ├── Timer/                     — Pomodoro
│   ├── StudyCoach/                — Daily Coach / Weekly Plan / Performance Review
│   ├── FocusCamera/               — AVCapture + Vision face detection
│   ├── Analytics/
│   └── Settings/
│
├── Services/
│   ├── GroqService.swift          — Groq API via backend proxy
│   ├── CrewAIService.swift        — CrewAI backend endpoints
│   ├── LearningStore.swift        — State management + UserDefaults persistence
│   ├── NoteScannerService.swift   — Vision OCR on-device
│   └── ...
│
└── Theme/
    └── StudyTheme.swift           — Colors, fonts, spacing, components

crew_backend/                      — Python FastAPI + CrewAI
├── main.py                        — Endpoints: /groq/completions, /study/*
├── crew.py                        — CrewAI agent definitions
└── requirements.txt
```

**Pattern:** MVVM + `@EnvironmentObject` dependency injection
**Concurrency:** `async/await` throughout, `@MainActor` on all ViewModels

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI |
| Architecture | MVVM |
| AI / LLM | Groq API — `llama-3.3-70b-versatile` |
| Multi-Agent AI | CrewAI 0.80.0 (Python) |
| Backend | FastAPI + uvicorn |
| Authentication | Firebase Auth (Email/Password) |
| PDF Processing | PDFKit + Vision OCR fallback |
| Computer Vision | Vision framework (VNRecognizeTextRequest, VNDetectFaceRectanglesRequest) |
| Camera | AVFoundation (AVCaptureSession) |
| Health Data | HealthKit |
| Notifications | UserNotifications |
| Persistence | UserDefaults + JSONEncoder/Decoder |
| TTS | AVSpeechSynthesizer |
| Haptics | UIImpactFeedbackGenerator |
| Animations | SwiftUI spring + matchedGeometryEffect |

---

## Getting Started

### Prerequisites
- Xcode 15+
- iOS 16.4+ simulator or physical iPhone
- Python 3.11+
- [Groq API key](https://console.groq.com/keys) (free tier available)

### 1. Clone
```bash
git clone https://github.com/h4kua/SmartStudy.git
cd SmartStudy
```

### 2. Start the Python backend
```bash
cd crew_backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Create `crew_backend/.env`:
```
GROQ_API_KEY=gsk_your_key_here
```

```bash
./start.sh
```

### 3. Open in Xcode
```bash
open FinalProject.xcodeproj
```

### 4. Run
Select iPhone 16 simulator and press **⌘R**.

The iOS app routes all AI calls through `http://localhost:8000` (simulator) or `http://10.24.162.130:8000` (physical device — update IP in `CrewAIService.swift`).

---

## Environment Variables

| Key | Where | Description |
|---|---|---|
| `GROQ_API_KEY` | `crew_backend/.env` | Your Groq key — never commit |

The Xcode scheme has `GROQ_API_KEY = ""` (empty) intentionally. The app never uses the key directly — all LLM calls go through the local FastAPI proxy which reads the key from `.env`.

> `GoogleService-Info.plist` is excluded from the repo — add your own from the [Firebase Console](https://console.firebase.google.com).

---

## Requirements Coverage

| Requirement | Implementation |
|---|---|
| SwiftUI UI | All screens built with SwiftUI |
| MVVM Pattern | `@MainActor ObservableObject` ViewModels, `@EnvironmentObject` injection |
| Networking / API | Groq REST API via FastAPI proxy — `async/await` + `URLSession` |
| Local Persistence | `UserDefaults` + `JSONEncoder` via `LearningStore` |
| Device APIs | Vision, AVFoundation, HealthKit, Speech, Notifications, PDFKit |
| File Handling | PDF + TXT import via `UIDocumentPickerViewController` |
| Animations | Spring transitions, `matchedGeometryEffect`, 3D card flip |
| Error Handling | All async calls in `do/catch` with user-facing error cards |
| Multi-Agent AI | CrewAI backend with 3 crews (DailyCoach, WeeklyPlan, PerformanceReview) |
| On-Device ML | Vision OCR + face detection (no data leaves device) |

---

## Developer

**Juan** — iOS Application Development
Deadline: July 1, 2026

---

## License

This project is for academic purposes only.
