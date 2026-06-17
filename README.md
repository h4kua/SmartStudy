# 🧠 AI Academic Mentor

> An intelligent iOS study companion powered by Groq (Llama 3 70B) and Firebase — built with SwiftUI, MVVM, HealthKit, and Speech Recognition.

---

## 📱 Screenshots

| Login | Home | AI Tutor |
|---|---|---|
| *Auth Screen* | *Dashboard* | *Chat* |

| Timer | Quiz | Analytics |
|---|---|---|
| *Pomodoro* | *Review Mode* | *Progress* |

---

## ✨ Features

### 🔐 Authentication (Firebase)
- **Google Sign-In** — one-tap OAuth via Google
- **Email / Password** — register or log in with email
- **Phone OTP** — SMS verification with country code picker
- **Anonymous / Guest** — explore without an account
- Password reset via email

### 🤖 AI Tutor (Groq × Llama 3 70B)
- Real-time chat with an academic AI tutor
- Voice input via **Speech Recognition** (`SFSpeechRecognizer`)
- Suggestion chips for quick questions
- Chat history with timestamps and text selection
- Clear chat button

### 📄 Document Analyzer
- Import PDF files via iOS file picker (`PDFKit`)
- AI-generated summary, key concepts, definitions, and study questions
- Analyzed documents saved locally with full history

### 📝 Quiz Generator
- AI-generated multiple-choice quizzes from any topic
- Configurable difficulty (Beginner / Intermediate / Advanced)
- Configurable question count (5 / 10 / 15)
- Haptic feedback on correct / wrong answers
- **Full Review Mode** — expandable cards with A/B/C/D options, color coding, and explanations

### 🃏 Flashcard System
- AI-generated flashcard decks with front, back, category, and difficulty
- Flip animation (3D rotation effect)
- **Swipe to review** — right = knew it ✅, left = didn't know ❌
- Mastery score and session complete screen

### ⏱ Pomodoro Study Timer
- 25-min Focus → 5-min Short Break → 15-min Long Break cycle
- Animated circular progress ring with phase-specific colors
- 4-dot cycle indicator
- Play / Pause / Reset / Skip controls
- Push notification when each session ends

### 🔔 Push Notifications
- Daily study reminder with custom time picker
- Pomodoro session completion alert
- Streak achievement notification
- Toggle on/off from Settings

### 📊 Analytics & Progress
- Weekly activity bar chart with animation
- Quiz stats: total, average score, best score, streak
- HealthKit integration: step count and sleep hours
- Recent quiz history list

### ⚙️ Settings
- **Subject Management** — add, edit, delete subjects with color and emoji picker
- Firebase user info (email / guest mode badge)
- AI configuration status (Groq model info)
- Sign out / clear all data

---

## 🏗 Architecture

```
FinalProject/
├── FinalProjectApp.swift          # App entry, Firebase configure, AppDelegate
├── MainTabView.swift              # Tab bar (Home / Tutor / Documents / Learn / Progress)
│
├── Features/
│   ├── Auth/
│   │   └── AuthView.swift         # Login: Google, Email, Phone, Anonymous
│   ├── Dashboard/
│   │   └── DashboardView.swift    # Hero banner, quick actions, recent activity
│   ├── AITutor/
│   │   ├── AITutorView.swift
│   │   └── AITutorViewModel.swift
│   ├── DocumentAnalyzer/
│   │   ├── DocumentAnalyzerView.swift
│   │   └── DocumentAnalyzerViewModel.swift
│   ├── Learn/
│   │   ├── LearnHubView.swift     # Segmented: Quizzes | Flashcards | Timer
│   │   ├── Quiz/
│   │   │   ├── QuizView.swift
│   │   │   ├── QuizSessionView.swift
│   │   │   ├── QuizViewModel.swift
│   │   │   └── QuizReviewView.swift   # Expandable answer review
│   │   └── Flashcards/
│   │       ├── FlashcardsView.swift
│   │       ├── FlashcardReviewView.swift
│   │       └── FlashcardsViewModel.swift
│   ├── Timer/
│   │   ├── TimerView.swift        # Pomodoro UI
│   │   └── TimerViewModel.swift   # Combine-based timer logic
│   ├── Analytics/
│   │   └── AnalyticsView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SubjectManagementView.swift
│
├── Services/
│   ├── GroqService.swift          # Groq API: chat, quiz gen, flashcard gen, doc analysis
│   ├── FirebaseAuthService.swift  # Firebase Auth singleton (all 4 providers)
│   ├── NotificationService.swift  # UNUserNotificationCenter wrapper
│   ├── LearningStore.swift        # @MainActor ObservableObject, UserDefaults persistence
│   ├── HealthKitService.swift     # Steps + sleep data
│   └── SpeechService.swift        # SFSpeechRecognizer wrapper
│
├── Models/
│   └── Models.swift               # Subject, ChatMessage, QuizQuestion, QuizSession,
│                                  #   Flashcard, FlashcardDeck, AnalyzedDocument
│
└── Theme/
    └── StudyTheme.swift           # Aurora color system, fonts, spacing, components
```

**Pattern:** MVVM + `@EnvironmentObject` dependency injection
**Concurrency:** `async/await` throughout, `@MainActor` on all ViewModels and Services

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI |
| Architecture | MVVM |
| AI / LLM | Groq API — `llama-3.3-70b-versatile` |
| Authentication | Firebase Auth (Google, Email, Phone, Anonymous) |
| Speech Input | `SFSpeechRecognizer` + `AVAudioEngine` |
| PDF Processing | `PDFKit` |
| Health Data | `HealthKit` |
| Notifications | `UserNotifications` |
| Persistence | `UserDefaults` + `JSONEncoder/Decoder` |
| Timer | `Combine` — `Timer.publish` |
| Animations | SwiftUI spring + `matchedGeometryEffect` |
| Haptics | `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator` |

---

## 🚀 Getting Started

### Prerequisites
- Xcode 14.3+
- iOS 16.0+ target
- A [Groq API key](https://console.groq.com/keys) (free tier available)
- A Firebase project with Authentication enabled

### 1. Clone the repo
```bash
git clone https://github.com/h4kua/SmartStudy.git
cd SmartStudy
```

### 2. Open in Xcode
```bash
open FinalProject.xcodeproj
```
Xcode will automatically resolve Swift Package dependencies (Firebase, GoogleSignIn).

### 3. Add your Groq API key
```
Xcode → Product → Scheme → Edit Scheme (⌘⇧,)
  → Run → Arguments → Environment Variables
  → Add: GROQ_API_KEY = gsk_YOUR_KEY_HERE
```

### 4. Firebase setup
- Add your own `GoogleService-Info.plist` from the [Firebase Console](https://console.firebase.google.com)
- Enable these Auth providers: **Email/Password**, **Phone**, **Google**, **Anonymous**

### 5. Run
Select an iPhone 15 simulator (or real device) and press **⌘R**.

---

## 🔑 Environment Variables

| Key | Required | Description |
|---|---|---|
| `GROQ_API_KEY` | ✅ | Your Groq API key — set in Xcode scheme only, never commit |

> `GoogleService-Info.plist` is the standard Firebase client config — safe to include in the bundle.

---

## 📋 Requirements Coverage

| Requirement | Implementation |
|---|---|
| SwiftUI UI | All screens built with SwiftUI |
| MVVM Pattern | `ObservableObject` ViewModels, `@EnvironmentObject` injection |
| Networking / API | Groq REST API with `async/await` + `URLSession` |
| Firebase | Auth (4 providers) + `FirebaseApp.configure()` |
| Local Persistence | `UserDefaults` + `JSONEncoder` via `LearningStore` |
| Device API | HealthKit, Speech Recognition, Push Notifications |
| File Handling | PDF import via `UIDocumentPickerViewController` |
| Animations | Spring, `matchedGeometryEffect`, `contentTransition` |
| Error Handling | All async calls wrapped in `do/catch` with user-friendly messages |

---

## 👤 Developer

**Juan** — iOS Application Development
Deadline: July 1, 2026

---

## 📄 License

This project is for academic purposes only.
