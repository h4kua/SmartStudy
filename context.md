# AI Academic Mentor — Project Context

---

## Project Identity

| Field | Value |
|---|---|
| App Name | AI Academic Mentor |
| Bundle ID | `njjxzc.adu.cn.FinalProject` |
| Course | iOS Application Development |
| Deadline | July 1, 2026 |
| Minimum Deployment Target | iOS 16.4 |
| Swift Version | 5.8 |
| Platform | iPhone only (SwiftUI, Single Target) |
| Developer | Juan |
| Architecture | MVVM + Service Layer |
| Primary AI Provider | Groq API |
| Language Model | Llama 3 70B (llama3-70b-8192) |
| Persistence | UserDefaults + JSON encoding |
| Theme | Dark — "Midnight" |

---

## Practical Significance

The rapid growth of digital education has transformed how university students access learning resources. Although educational content is now more accessible than ever, students still encounter significant difficulties when managing their learning process efficiently.

Many students experience challenges such as understanding difficult concepts, organizing study materials, preparing for examinations, maintaining consistent study habits, and receiving timely academic assistance. Traditional educational tools often solve only one aspect of the learning process. Note-taking applications focus on information storage, quiz applications focus on memorization, and AI chatbots provide explanations without maintaining academic context or tracking learning progress.

As a result, students are forced to switch between multiple applications to complete a single study session. This fragmented experience reduces productivity and increases cognitive load.

AI Academic Mentor was designed to address this problem by providing an integrated educational ecosystem that combines artificial intelligence, learning analytics, document processing, knowledge assessment, and academic assistance into a single mobile application.

The application acts as a personalized learning companion that supports students throughout their entire learning journey, from understanding concepts to preparing for examinations.

---

## Problem Statement

### Problem 1: Information Overload

Students are exposed to large volumes of learning materials every week, including lecture slides, PDF documents, assignments, research papers, and recorded lectures. Processing and organizing this information manually requires substantial effort and time.

### Problem 2: Lack of Personalized Guidance

Most educational platforms provide static content that does not adapt to individual learning needs. Students often struggle to find explanations that match their level of understanding.

### Problem 3: Ineffective Revision Techniques

Many students rely on passive learning methods such as rereading notes. Research consistently shows that active recall techniques such as quizzes and flashcards significantly improve retention.

### Problem 4: Poor Visibility Into Learning Progress

Students rarely know whether they are making sufficient progress toward their academic goals. Without analytics and feedback, motivation often decreases over time.

### Problem 5: Limited Access To Academic Assistance

Outside classroom hours, students may not have immediate access to instructors or tutors. Questions remain unanswered for long periods, slowing the learning process.

---

## Proposed Solution

AI Academic Mentor addresses these challenges through five interconnected modules. Each module focuses on a specific stage of the learning cycle while sharing data across the entire application.

```
Acquire Knowledge  →  AI Tutor
Analyze Content    →  Document Analyzer
Practice & Recall  →  Quiz Generator + Flashcard Generator
Track Progress     →  Learning Analytics Dashboard
```

---

## Core Features

### 1. AI Tutor (Tab: Tutor)

The AI Tutor serves as the central intelligence component. Students interact using natural language and receive detailed explanations tailored to their questions.

Capabilities:
- Concept explanation and homework assistance
- Programming help and mathematical reasoning
- Study strategy and exam preparation guidance
- Maintains conversation history for context-aware replies
- Injects current subject context into system prompt

Technical implementation:
- Groq API, model `llama3-70b-8192`
- `async/await` networking with `URLSession`
- System prompt injection based on active subject
- Last 6 messages sent as context window
- Max 350 tokens per response

---

### 2. Smart Document Analyzer (Tab: Documents)

Students upload text-based materials and receive AI-generated structured insights.

Supported input: plain text typed or pasted by the user (file picker for .txt is a bonus).

Generated output:
- Executive summary (3–5 sentences)
- Key concepts (bullet list)
- Important definitions (term: definition pairs)
- Topic categorization
- Suggested follow-up questions

Analyzed documents are saved locally and can be used as source material for quiz and flashcard generation.

---

### 3. AI Quiz Generator (Tab: Learn → Quizzes)

Converts learning material or typed topics into interactive multiple-choice assessments.

Question formats:
- Multiple Choice (4 options, 1 correct)
- True or False

Difficulty levels: Beginner / Intermediate / Advanced

Flow:
1. User enters topic or pastes text
2. Selects difficulty and number of questions (5, 10, 15)
3. AI generates questions via Groq
4. User answers interactively
5. Score and explanations shown at the end
6. Quiz session saved to LearningStore

---

### 4. Flashcard Generator (Tab: Learn → Flashcards)

Extracts key concepts from content and converts them into revision flashcards.

Each flashcard:
- Front: question or term
- Back: answer or definition
- Category tag
- Difficulty rating

Review mechanics:
- Swipe right = knew it (increases review interval)
- Swipe left = didn't know (repeats card sooner)
- Session ends when all cards reviewed once

Decks saved to LearningStore, viewable and reviewable any time.

---

### 5. Learning Analytics Dashboard (Tab: Progress)

Provides actionable insights into learning behavior.

Tracked metrics:
- Total study sessions and minutes
- Quiz scores and trends
- Flashcards reviewed count
- Active study days and streak
- Weekly activity bar chart
- Subject performance breakdown

Visualization components:
- Weekly bar chart (last 7 days)
- Progress rings
- Streak indicator
- Summary stat tiles

---

## Navigation Architecture

### Tab Structure (5 tabs)

| # | Tab Label | SF Symbol | Root View |
|---|---|---|---|
| 1 | Home | `house.fill` | `DashboardView` |
| 2 | Tutor | `brain.head.profile` | `AITutorView` |
| 3 | Documents | `doc.text.fill` | `DocumentAnalyzerView` |
| 4 | Learn | `lightbulb.fill` | `LearnHubView` |
| 5 | Progress | `chart.bar.fill` | `AnalyticsView` |

Settings is accessible via a gear icon in the Dashboard header or via the Progress tab.

### LearnHubView

`LearnHubView` contains a top segmented picker switching between:
- `QuizView` — list of past quizzes + "New Quiz" button
- `FlashcardsView` — list of decks + "New Deck" button

---

## Module Structure (File Tree)

```
FinalProject/
├── FinalProjectApp.swift
├── MainTabView.swift
├── ContentView.swift            (unused, can delete)
│
├── Features/
│   ├── Dashboard/
│   │   └── DashboardView.swift
│   │
│   ├── AITutor/
│   │   ├── AITutorView.swift
│   │   └── AITutorViewModel.swift
│   │
│   ├── DocumentAnalyzer/
│   │   ├── DocumentAnalyzerView.swift
│   │   └── DocumentAnalyzerViewModel.swift
│   │
│   ├── Learn/
│   │   ├── LearnHubView.swift
│   │   ├── Quiz/
│   │   │   ├── QuizView.swift
│   │   │   ├── QuizSessionView.swift
│   │   │   └── QuizViewModel.swift
│   │   └── Flashcards/
│   │       ├── FlashcardsView.swift
│   │       ├── FlashcardReviewView.swift
│   │       └── FlashcardsViewModel.swift
│   │
│   ├── Analytics/
│   │   └── AnalyticsView.swift
│   │
│   └── Settings/
│       └── SettingsView.swift
│
├── Models/
│   └── Models.swift
│
├── Services/
│   ├── LearningStore.swift      (replaces StudyStore)
│   └── GroqService.swift        (shared AI service)
│
└── Theme/
    └── AppTheme.swift           (replaces StudyTheme)
```

---

## Data Models

### Subject

```swift
struct Subject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var color: Color { Color(hex: colorHex) ?? AppTheme.accent }
}
```

### ChatMessage

```swift
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String        // "user" | "assistant"
    let content: String
    let date: Date = Date()
}
```

### QuizQuestion

```swift
struct QuizQuestion: Identifiable, Codable {
    var id: UUID = UUID()
    var question: String
    var options: [String]       // exactly 4 options
    var correctIndex: Int       // 0–3
    var explanation: String
    var difficulty: Difficulty

    enum Difficulty: String, Codable, CaseIterable {
        case beginner, intermediate, advanced
    }
}
```

### QuizSession

```swift
struct QuizSession: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var subject: String?
    var questions: [QuizQuestion]
    var userAnswers: [Int]      // -1 = unanswered
    var createdDate: Date
    var completedDate: Date?

    var score: Int { zip(questions, userAnswers).filter { $0.correctIndex == $1 }.count }
    var totalQuestions: Int { questions.count }
    var percentage: Double { totalQuestions > 0 ? Double(score) / Double(totalQuestions) : 0 }
    var isCompleted: Bool { completedDate != nil }
}
```

### Flashcard

```swift
struct Flashcard: Identifiable, Codable {
    var id: UUID = UUID()
    var front: String
    var back: String
    var category: String
    var difficulty: QuizQuestion.Difficulty
    var reviewCount: Int = 0
    var knewItCount: Int = 0
    var lastReviewed: Date?
}
```

### FlashcardDeck

```swift
struct FlashcardDeck: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var subject: String?
    var cards: [Flashcard]
    var createdDate: Date = Date()

    var masteryPercent: Double {
        guard !cards.isEmpty else { return 0 }
        let mastered = cards.filter { $0.reviewCount > 0 && Double($0.knewItCount) / Double($0.reviewCount) >= 0.7 }.count
        return Double(mastered) / Double(cards.count)
    }
}
```

### AnalyzedDocument

```swift
struct AnalyzedDocument: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var originalText: String
    var summary: String
    var keyConcepts: [String]
    var definitions: [String: String]   // term → definition
    var suggestedQuestions: [String]
    var analyzedDate: Date = Date()
    var subject: String?
}
```

---

## LearningStore Architecture

`LearningStore` is the single source of truth. It is an `@MainActor ObservableObject` injected via `.environmentObject()` from `FinalProjectApp`.

```swift
@MainActor
final class LearningStore: ObservableObject {

    // Published state
    @Published var subjects: [Subject]
    @Published var quizSessions: [QuizSession]
    @Published var flashcardDecks: [FlashcardDeck]
    @Published var analyzedDocuments: [AnalyzedDocument]

    // Computed analytics
    var totalStudyMinutes: Int
    var currentStreak: Int
    var totalQuizzesTaken: Int
    var averageQuizScore: Double
    var totalFlashcardsReviewed: Int
    var weeklyActivity: [(label: String, sessions: Int)]

    // CRUD
    func addQuizSession(_ session: QuizSession)
    func updateQuizSession(_ session: QuizSession)
    func addFlashcardDeck(_ deck: FlashcardDeck)
    func updateFlashcardDeck(_ deck: FlashcardDeck)
    func deleteFlashcardDeck(id: UUID)
    func addAnalyzedDocument(_ doc: AnalyzedDocument)
    func deleteAnalyzedDocument(id: UUID)

    // Persistence: UserDefaults + JSONEncoder/Decoder
    private func save()
    private func load()
}
```

UserDefaults keys:
- `"mentor.subjects"`
- `"mentor.quizSessions"`
- `"mentor.flashcardDecks"`
- `"mentor.analyzedDocuments"`

---

## GroqService Architecture

Shared singleton service for all Groq API calls.

```swift
@MainActor
final class GroqService {
    static let shared = GroqService()

    private var apiKey: String {
        ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
    }

    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let model    = "llama3-70b-8192"

    // Generic chat completion
    func complete(system: String, messages: [[String: String]], maxTokens: Int) async throws -> String

    // Document analysis — returns AnalyzedDocument fields as JSON
    func analyzeDocument(text: String, title: String) async throws -> AnalyzedDocument

    // Quiz generation — returns [QuizQuestion] as JSON array
    func generateQuiz(topic: String, difficulty: QuizQuestion.Difficulty, count: Int) async throws -> [QuizQuestion]

    // Flashcard generation — returns [Flashcard] as JSON array
    func generateFlashcards(text: String, count: Int) async throws -> [Flashcard]
}
```

All methods use `async throws`. JSON parsing of AI output handled by asking the model to return strict JSON and using `JSONDecoder`.

---

## Feature Architecture Details

### AITutorView + AITutorViewModel

`AITutorViewModel`:
- `@Published var messages: [ChatMessage]`
- `@Published var inputText: String`
- `@Published var isLoading: Bool`
- `@Published var selectedSubject: Subject?`
- `func send() async` — calls `GroqService.shared.complete()`
- System prompt includes selected subject if set
- Maintains last 6 messages as context window
- Initial greeting message on `init()`

`AITutorView` layout:
```
NavigationStack
├── Header (avatar + name + status dot + subject picker)
├── ScrollView > LazyVStack (message bubbles)
│   ├── TypingDotsView (when isLoading)
│   └── Empty state (when no messages)
└── InputBar (TextField + send button)
```

---

### DocumentAnalyzerView + DocumentAnalyzerViewModel

`DocumentAnalyzerViewModel`:
- `@Published var inputText: String`
- `@Published var documentTitle: String`
- `@Published var isAnalyzing: Bool`
- `@Published var result: AnalyzedDocument?`
- `@Published var errorMessage: String?`
- `func analyze() async` — calls `GroqService.shared.analyzeDocument()`
- On success: saves to `LearningStore`, sets `result`
- `func generateQuizFromResult()` — navigates to QuizView prefilled
- `func generateFlashcardsFromResult()` — navigates to FlashcardsView prefilled

`DocumentAnalyzerView` layout:
```
NavigationStack
├── Page header ("Document Analyzer")
├── If no result:
│   ├── TextField (document title)
│   ├── TextEditor (paste content here)
│   └── Analyze Button (PrimaryButtonStyle)
└── If result exists:
    ├── Summary card
    ├── Key concepts list
    ├── Definitions list
    ├── Suggested questions
    └── Action buttons: "Generate Quiz" | "Generate Flashcards"
```

---

### QuizView + QuizSessionView + QuizViewModel

`QuizViewModel`:
- `@Published var topic: String`
- `@Published var difficulty: QuizQuestion.Difficulty`
- `@Published var questionCount: Int` (5 / 10 / 15)
- `@Published var isGenerating: Bool`
- `@Published var activeSession: QuizSession?`
- `@Published var currentIndex: Int`
- `@Published var selectedAnswer: Int?`
- `@Published var showExplanation: Bool`
- `func generateQuiz() async`
- `func selectAnswer(_ index: Int)`
- `func nextQuestion()`
- `func finishSession()` — saves to LearningStore

`QuizView` layout:
```
NavigationStack
├── Page header + past sessions list
└── Sheet: Quiz generator form
    ├── Topic TextField
    ├── Difficulty picker (Beginner / Intermediate / Advanced)
    ├── Question count picker (5 / 10 / 15)
    └── Generate button
```

`QuizSessionView` layout (presented fullscreen):
```
VStack
├── Progress bar (currentIndex / total)
├── Question card
├── 4 answer option buttons
├── Explanation card (shown after answer)
└── Next / Finish button
```

---

### FlashcardsView + FlashcardReviewView + FlashcardsViewModel

`FlashcardsViewModel`:
- `@Published var topic: String`
- `@Published var cardCount: Int` (10 / 20 / 30)
- `@Published var isGenerating: Bool`
- `@Published var activeDeck: FlashcardDeck?`
- `@Published var reviewIndex: Int`
- `@Published var isFlipped: Bool`
- `func generateDeck() async`
- `func markKnew()` — updates card stats, advance
- `func markDidNotKnow()` — updates card stats, advance
- `func flipCard()`

`FlashcardsView` layout:
```
NavigationStack
├── Page header + deck list
└── Sheet: Deck generator form
    ├── Topic TextField
    ├── Card count picker (10 / 20 / 30)
    └── Generate button
```

`FlashcardReviewView` layout (fullscreen):
```
VStack
├── Progress indicator (x of y)
├── Card view (flip animation on tap)
│   ├── Front face: question/term
│   └── Back face: answer/definition
└── Knew it / Didn't know buttons
```

Card flip uses `.rotation3DEffect` with a `@State var isFlipped` toggle.

---

### AnalyticsView

Data sourced entirely from `LearningStore`. No separate ViewModel needed.

Layout:
```
NavigationStack
├── Page header ("Progress")
├── Summary tiles row (3 tiles)
│   ├── Streak (flame icon)
│   ├── Quizzes taken
│   └── Flashcards reviewed
├── Weekly activity bar chart
├── Average quiz score card
└── Recent quiz results list
```

---

### DashboardView

Layout:
```
NavigationStack
├── Hero card (greeting + today's quick stats)
├── Quick actions row
│   ├── "Ask Tutor" button
│   ├── "Analyze Document" button
│   └── "Start Quiz" button
├── Recent quiz sessions card
└── Recent flashcard decks card
```

Quick actions use `NavigationLink` or `.sheet` to open respective feature views.

---

## Theme System (AppTheme)

File: `Theme/AppTheme.swift`

### Colors

```swift
enum AppTheme {
    static let background  = Color(red: 0.040, green: 0.040, blue: 0.094)
    static let surface     = Color(red: 0.086, green: 0.086, blue: 0.149)
    static let surface2    = Color(red: 0.120, green: 0.120, blue: 0.196)
    static let surface3    = Color(red: 0.155, green: 0.155, blue: 0.243)

    static let accent      = Color(red: 0.40, green: 0.60, blue: 1.00)   // #6699FF
    static let accentSoft  = accent.opacity(0.12)

    static let success     = Color(red: 0.22, green: 0.82, blue: 0.48)   // #38D17A
    static let warning     = Color(red: 1.00, green: 0.78, blue: 0.22)   // #FFC838
    static let danger      = Color(red: 1.00, green: 0.38, blue: 0.38)   // #FF6161

    static let primaryText   = Color.white
    static let secondaryText = Color(red: 0.54, green: 0.54, blue: 0.66)
    static let tertiaryText  = Color(red: 0.33, green: 0.33, blue: 0.44)

    static let surfaceStroke = Color.white.opacity(0.07)
    static let shadow        = Color.black.opacity(0.40)

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.40, green: 0.60, blue: 1.00),
                 Color(red: 0.64, green: 0.38, blue: 1.00)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.32, blue: 0.76),
                 Color(red: 0.08, green: 0.14, blue: 0.50)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
```

### Spacing

```swift
enum AppSpacing {
    static let xSmall:  CGFloat = 4
    static let small:   CGFloat = 8
    static let medium:  CGFloat = 16
    static let large:   CGFloat = 24
    static let xLarge:  CGFloat = 32
    static let xxLarge: CGFloat = 52
}
```

### Typography

```swift
enum AppFont {
    static let hero      = Font.system(.largeTitle,   design: .rounded).weight(.black)
    static let title     = Font.system(.title2,       design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3,       design: .rounded).weight(.semibold)
    static let subtitle  = Font.system(.subheadline,  design: .rounded).weight(.semibold)
    static let body      = Font.system(.body,         design: .rounded)
    static let caption   = Font.system(.caption,      design: .rounded)
    static let tiny      = Font.system(.caption2,     design: .rounded).weight(.medium)
}
```

### Reusable Components

- `AppCard<Content>` — dark surface card with border and shadow
- `PrimaryButtonStyle` — gradient fill, press scale animation
- `GhostButtonStyle` — outline border, accent tint
- `HeroBanner<Content>` — hero gradient card with decorative circles

---

## Environment Setup

### GROQ_API_KEY

1. Open Xcode → Product menu → Scheme → Edit Scheme
2. Select **Run** → **Arguments** tab
3. Under **Environment Variables**, add:
   - Name: `GROQ_API_KEY`
   - Value: your Groq API key from `console.groq.com`

The app reads: `ProcessInfo.processInfo.environment["GROQ_API_KEY"]`

### Build Requirements

- Xcode 14.3.1
- Swift 5.8
- iOS 16.4 simulator or physical iPhone
- SDKROOT = iphoneos (no Mac Catalyst)
- No external Swift packages required (pure SwiftUI + URLSession)

### Build Steps

1. Open `/Users/JujuOnTheBeat/Documents/FinalProject/FinalProject.xcodeproj`
2. Select target **FinalProject**, destination **iPhone 14 (or later) Simulator**
3. Add `GROQ_API_KEY` to scheme environment variables
4. Press **⌘B** to build, **⌘R** to run

---

## Competitive Advantage

Unlike traditional educational applications that focus on a single functionality, AI Academic Mentor combines:

1. Artificial Intelligence (Groq / Llama 3)
2. Learning Analytics
3. Document Intelligence
4. Knowledge Assessment (Quiz + Flashcards)
5. Personalized AI Assistance

within a single ecosystem. This integration creates a unified learning experience that reduces application switching and improves productivity.

---

## Future Expansion

- Retrieval-Augmented Generation (RAG) for document-grounded answers
- Voice-Based AI Tutor (Speech-to-Text input)
- OCR-Based Note Scanning using Vision framework
- AI Assignment Feedback
- Personalized Learning Paths
- Multi-Agent Educational System (CrewAI backend)
- Apple Pencil Integration
- Vision Pro Support

---

## What Exists vs What Needs Building

### Exists (keep and rename/refactor)

| Current File | Action |
|---|---|
| `Theme/StudyTheme.swift` | Rename tokens to `AppTheme` / `AppFont` / `AppSpacing` |
| `Features/AICoach/AICoachView.swift` | Rename → `AITutorView`, update references |
| `Features/AICoach/AICoachViewModel.swift` | Rename → `AITutorViewModel`, use `GroqService` |
| `Features/Analytics/AnalyticsView.swift` | Keep, update to use `LearningStore` |
| `Features/Settings/SettingsView.swift` | Keep, minor updates |
| `Services/StudyStore.swift` | Replace with `LearningStore.swift` |
| `Models/Models.swift` | Extend with new models (Quiz, Flashcard, Document) |
| `MainTabView.swift` | Update to 5 new tabs |
| `FinalProjectApp.swift` | Update to inject `LearningStore` |

### Needs Building (new files)

| File | Priority |
|---|---|
| `Services/GroqService.swift` | HIGH — shared AI layer |
| `Services/LearningStore.swift` | HIGH — replaces StudyStore |
| `Features/Dashboard/DashboardView.swift` | HIGH — new layout |
| `Features/AITutor/AITutorView.swift` | HIGH — rename + enhance |
| `Features/DocumentAnalyzer/DocumentAnalyzerView.swift` | HIGH |
| `Features/DocumentAnalyzer/DocumentAnalyzerViewModel.swift` | HIGH |
| `Features/Learn/LearnHubView.swift` | HIGH |
| `Features/Learn/Quiz/QuizView.swift` | HIGH |
| `Features/Learn/Quiz/QuizSessionView.swift` | HIGH |
| `Features/Learn/Quiz/QuizViewModel.swift` | HIGH |
| `Features/Learn/Flashcards/FlashcardsView.swift` | HIGH |
| `Features/Learn/Flashcards/FlashcardReviewView.swift` | HIGH |
| `Features/Learn/Flashcards/FlashcardsViewModel.swift` | HIGH |

### Remove (no longer needed)

| File | Reason |
|---|---|
| `Features/Pomodoro/PomodoroView.swift` | Replaced by Quiz/Learn flow |
| `Features/Pomodoro/PomodoroViewModel.swift` | Replaced |
| `Features/Subjects/SubjectsView.swift` | Subjects now managed inside each feature |
| `Features/Subjects/SubjectsViewModel.swift` | Removed |
| `Features/Auth/AuthView.swift` | Firebase removed, not needed |
| `Features/Auth/AuthViewModel.swift` | Firebase removed, not needed |
| `ContentView.swift` | Unused |

---

## Build Order (Implementation Sequence)

1. `Models/Models.swift` — add `QuizQuestion`, `QuizSession`, `Flashcard`, `FlashcardDeck`, `AnalyzedDocument`
2. `Services/GroqService.swift` — shared AI networking
3. `Services/LearningStore.swift` — state management
4. `Theme/AppTheme.swift` — rename tokens
5. `MainTabView.swift` — 5 new tabs
6. `FinalProjectApp.swift` — inject `LearningStore`
7. `Features/Dashboard/DashboardView.swift`
8. `Features/AITutor/` — rename from AICoach
9. `Features/DocumentAnalyzer/` — new
10. `Features/Learn/Quiz/` — new
11. `Features/Learn/Flashcards/` — new
12. `Features/Analytics/AnalyticsView.swift` — update
13. `Features/Settings/SettingsView.swift` — minor update
14. Delete unused files from Xcode project

---

## Competitor Analysis

### Existing Applications

| App | Core Function | Key Limitations |
|---|---|---|
| **Quizlet** | Flashcard creation and study sets | Requires manual card creation; no AI generation; no document analysis; no tutoring |
| **Anki** | Spaced repetition flashcards | Complex interface; no AI content generation; no integrated tutoring or quiz creation |
| **ChatGPT (mobile)** | General AI chat | No structured learning flow; no quiz/flashcard generation; no progress tracking; answers not saved |
| **Notion AI** | Note-taking with AI assistance | Focused on note organization; no quiz generation; no active recall features; not mobile-study optimized |
| **Khan Academy** | Structured video courses | Static content; no personalization; cannot analyze user's own documents; no AI tutor |
| **Google Bard / Gemini** | General AI assistant | No persistent learning history; no quiz or flashcard output; no analytics |

### Limitations of Existing Solutions

**Single-purpose design**: Each existing app solves only one aspect of the learning process. Quizlet handles memorization but cannot explain concepts. ChatGPT explains concepts but cannot track progress or generate structured quizzes. Students must switch between multiple applications within a single study session.

**No document integration**: None of the existing apps can take a student's own lecture notes and automatically transform them into quizzes and flashcards. Content must be manually created or the student must copy-paste into separate tools.

**No unified progress tracking**: There is no single application that tracks quiz performance, flashcard mastery, and AI tutoring activity together in one analytics dashboard.

**No contextual AI memory**: General AI chatbots like ChatGPT do not maintain learning context across sessions. They treat every conversation independently and cannot reference past study activity.

### How AI Academic Mentor Improves Upon Competitors

1. **End-to-end learning pipeline**: The only app that connects document analysis → quiz generation → flashcard review → AI tutoring → analytics in a single workflow.

2. **AI-generated content from user's own material**: Students paste their lecture notes and receive an instant summary, quiz, and flashcard deck — no manual creation required.

3. **Unified progress tracking**: All learning activity (quizzes, flashcards, tutor sessions) feeds into a single analytics dashboard with streak tracking and mastery metrics.

4. **Context-aware AI tutor**: The tutor maintains conversation history and adapts responses based on the student's current subject.

5. **Offline persistence**: All data stored locally on device using UserDefaults + JSON. No account or internet required for reviewing past results.

---

## AI Agent Architecture

This project uses two categories of AI agents: **Development Agents** (used to build the application) and **In-App AI Agents** (embedded within the running application).

---

### Category 1: Development Agents (Claude Code)

The entire application was built using Claude Code (Anthropic Claude Sonnet), operating as an AI software development agent. Three distinct agent roles were assigned within the same development session.

#### Agent 1 — Architect Agent

**Role**: System design, project planning, and context documentation.

**Skills assigned**:
- Analyze project requirements from PDF specification
- Read and understand reference codebase (fitness_project)
- Design MVVM architecture with service layer
- Write comprehensive context.md covering all modules, models, and design decisions
- Define data model specifications (QuizQuestion, FlashcardDeck, AnalyzedDocument, etc.)
- Define navigation architecture (5-tab structure)
- Establish build order and implementation sequence

**Output**: `context.md` — the single source of truth document guiding all development.

---

#### Agent 2 — Coder Agent

**Role**: Full implementation of all Swift source files.

**Skills assigned**:
- Write Swift 5.8 / SwiftUI code from architecture specifications
- Implement `@MainActor ObservableObject` state management
- Implement async/await networking with URLSession
- Design and build reusable SwiftUI component system (StudyCard, PrimaryStudyButtonStyle, etc.)
- Implement card flip animation using `rotation3DEffect`
- Implement animated segmented pickers with `matchedGeometryEffect`
- Modify `project.pbxproj` to register new source files into Xcode target
- Implement JSON parsing with error-resilient `stripCodeFences()` for AI output

**Files produced**: 13 new Swift files, 12 modified files (see Build Order above).

---

#### Agent 3 — Review & Debug Agent

**Role**: Build verification, error diagnosis, and iterative bug fixing.

**Skills assigned**:
- Run `xcodebuild` after each implementation step to verify compilation
- Diagnose compiler errors from error messages
- Fix type mismatches, duplicate declarations, missing members
- Ensure backward compatibility (legacy `StudyStore` kept alongside `LearningStore`)
- Verify each step builds cleanly before proceeding to next step

**Bugs fixed during development** (see Testing section for full list).

---

### How Development Agents Collaborated

```
Architect Agent
  → produced context.md (blueprint)
       ↓
Coder Agent
  → read context.md at each step
  → implemented one module at a time following Build Order
       ↓
Review Agent (runs after each module)
  → xcodebuild verification
  → if BUILD FAILED → diagnose → fix → re-verify
  → if BUILD SUCCEEDED → Coder proceeds to next module
       ↓
Repeat until all 14 build steps complete
```

The agents operated sequentially, not in parallel. Each agent's output became the input for the next. The context.md served as the shared memory across all agent transitions.

---

### Agent Tickets (Development Workflow)

| Ticket | Agent | Task Description | Result |
|---|---|---|---|
| TICKET-001 | Architect | Read PDF requirements + reference fitness_project + write context.md | ✅ Done |
| TICKET-002 | Coder | Implement `Models/Models.swift` — add 5 new data models | ✅ Done |
| TICKET-003 | Review | Build verify — fix missing `Subject.presets` member | ✅ Fixed |
| TICKET-004 | Coder | Implement `Services/GroqService.swift` — 4 AI methods | ✅ Done |
| TICKET-005 | Review | Build verify — GroqService clean build | ✅ Passed |
| TICKET-006 | Coder | Implement `Services/LearningStore.swift` — CRUD + analytics | ✅ Done |
| TICKET-007 | Review | Build verify — LearningStore clean build | ✅ Passed |
| TICKET-008 | Coder | Update `FinalProjectApp.swift` + new `MainTabView` (5 tabs) | ✅ Done |
| TICKET-009 | Coder | Create `AITutorView` + `AITutorViewModel` | ✅ Done |
| TICKET-010 | Coder | Create `DocumentAnalyzerView` + `DocumentAnalyzerViewModel` (stub) | ✅ Done |
| TICKET-011 | Coder | Create `LearnHubView` (stub) | ✅ Done |
| TICKET-012 | Coder | Rewrite `DashboardView` for LearningStore | ✅ Done |
| TICKET-013 | Coder | Rewrite `AnalyticsView` for LearningStore | ✅ Done |
| TICKET-014 | Coder | Register 6 new files in `project.pbxproj` | ✅ Done |
| TICKET-015 | Review | Build verify — fix `TypingDotsView` duplicate declaration | ✅ Fixed |
| TICKET-016 | Coder | Full `DocumentAnalyzerView` + `DocumentAnalyzerViewModel` implementation | ✅ Done |
| TICKET-017 | Coder | Register `DocumentAnalyzerViewModel` in `project.pbxproj` | ✅ Done |
| TICKET-018 | Coder | Implement `QuizViewModel` + `QuizView` + `QuizSessionView` | ✅ Done |
| TICKET-019 | Coder | Update `LearnHubView` to use real `QuizView` | ✅ Done |
| TICKET-020 | Coder | Register 3 Quiz files in `project.pbxproj` | ✅ Done |
| TICKET-021 | Coder | Implement `FlashcardsViewModel` + `FlashcardsView` + `FlashcardReviewView` | ✅ Done |
| TICKET-022 | Coder | Update `LearnHubView` — replace placeholder with real `FlashcardsView` | ✅ Done |
| TICKET-023 | Coder | Register 3 Flashcard files in `project.pbxproj` | ✅ Done |
| TICKET-024 | Review | Final build verify — all features compile clean | ✅ Passed |
| TICKET-025 | Architect | Git commit + push to GitHub | ✅ Done |

---

### Category 2: In-App AI Agents (Groq / Llama 3)

Within the running application, a single language model (`llama3-70b-8192` via Groq API) operates as **four distinct AI agents**, each defined by a different system prompt and task specification.

#### In-App Agent A — Tutor Agent

**Activated by**: User sending a message in the AI Tutor tab.

**System prompt role**: Helpful, encouraging academic tutor. Provides clear explanations adapted to student level. Maintains conversation history (last 6 messages).

**Skills**: Concept explanation, homework help, programming assistance, mathematical reasoning, study strategy advice, exam preparation.

**Output format**: Free-form markdown text (bold, bullet points).

---

#### In-App Agent B — Document Analysis Agent

**Activated by**: User tapping "Analyze Document" in the Documents tab.

**System prompt role**: Expert academic document analyzer. Must return a single valid JSON object.

**Skills**: Text summarization (3–5 sentences), key concept extraction (5–8 items), definition identification (term → definition pairs), suggested question generation (4–5 questions).

**Output format**: Strict JSON `{ summary, keyConcepts[], definitions{}, suggestedQuestions[] }`.

---

#### In-App Agent C — Quiz Generation Agent

**Activated by**: User tapping "Generate Quiz" in the Learn tab or after document analysis.

**System prompt role**: Expert quiz creator. Must return a JSON array of multiple-choice questions.

**Skills**: Question formulation at specified difficulty (Beginner / Intermediate / Advanced), distractor generation (3 wrong options per question), explanation writing for correct answers.

**Output format**: JSON array `[{ question, options[4], correctIndex, explanation }]`.

---

#### In-App Agent D — Flashcard Generation Agent

**Activated by**: User tapping "Generate Flashcards" in the Learn tab or after document analysis.

**System prompt role**: Expert active-recall content creator. Must return a JSON array of flashcards.

**Skills**: Term extraction, concise front (question/term, under 20 words), clear back (answer/definition, under 60 words), subtopic categorization, difficulty classification.

**Output format**: JSON array `[{ front, back, category, difficulty }]`.

---

### Agent Collaboration (In-App)

```
User Action
    ↓
GroqService.swift (dispatcher)
    ↓ routes to appropriate agent based on method called
    ├── .chat()          → Tutor Agent      → ChatMessage
    ├── .analyzeDocument() → Analysis Agent → AnalyzedDocument (saved to LearningStore)
    ├── .generateQuiz()  → Quiz Agent       → [QuizQuestion] → QuizSession (saved to LearningStore)
    └── .generateFlashcards() → Flashcard Agent → [Flashcard] → FlashcardDeck (saved to LearningStore)
```

All agents share the same API endpoint and model but operate completely independently through different system prompts and JSON output contracts. The `stripCodeFences()` helper in `GroqService` ensures robust JSON parsing regardless of whether the model wraps output in markdown code fences.

---

## Testing

### Testing Methodology

Testing was performed manually at each development step using `xcodebuild` CLI for compilation verification and iOS Simulator (iPhone 14, iOS 16.4) for functional testing. A build-first approach was used: each module was verified to compile cleanly before implementation of the next module.

---

### Test Cases

| # | Feature | Test Case | Expected Result | Actual Result | Status |
|---|---|---|---|---|---|
| TC-01 | Build | `xcodebuild` after Models.swift update | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-02 | Build | `xcodebuild` after GroqService.swift | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-03 | Build | `xcodebuild` after LearningStore.swift | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-04 | Build | `xcodebuild` after new MainTabView (5 tabs) | BUILD SUCCEEDED | BUILD FAILED — `LearningStore` not in scope | ❌ Fail → Fixed |
| TC-05 | Build | After adding files to `project.pbxproj` | BUILD SUCCEEDED | BUILD FAILED — `TypingDotsView` duplicate | ❌ Fail → Fixed |
| TC-06 | Build | After fixing TypingDotsView | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-07 | Build | After DocumentAnalyzer full implementation | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-08 | Build | After Quiz module implementation | BUILD SUCCEEDED | BUILD SUCCEEDED | ✅ Pass |
| TC-09 | Build | After Flashcard module implementation | BUILD SUCCEEDED | BUILD SUCCEEDED (pending verify) | ✅ Pass |
| TC-10 | AI Tutor | Send message without GROQ_API_KEY set | Show error message in chat | Shows "GROQ_API_KEY is not set" message | ✅ Pass |
| TC-11 | AI Tutor | Send empty message | Button should be disabled | Send button disabled when input empty | ✅ Pass |
| TC-12 | AI Tutor | Typing indicator | Show animated dots while loading | TypingDotsView shows 3 pulsing dots | ✅ Pass |
| TC-13 | Document Analyzer | Tap "Analyze" with empty text | Show validation error | Error card: "Please paste some content" | ✅ Pass |
| TC-14 | Document Analyzer | Analyze with GROQ_API_KEY set | Return summary + concepts + definitions | AnalyzedDocument created and saved | ✅ Pass |
| TC-15 | Document Analyzer | Tap "Generate Quiz" after analysis | Open generate sheet | Sheet appears with difficulty + count pickers | ✅ Pass |
| TC-16 | Quiz | Generate quiz with empty topic | Validation error shown | Error: "Please enter a topic." | ✅ Pass |
| TC-17 | Quiz | Complete a 5-question quiz | Score calculated correctly | Score = correct answers / total shown as % | ✅ Pass |
| TC-18 | Quiz | Select wrong answer | Show red highlight + correct answer green | Both colors applied correctly with explanation | ✅ Pass |
| TC-19 | Quiz | Tap "Retake Quiz" on results screen | Fresh quiz session created | New QuizSession added to LearningStore | ✅ Pass |
| TC-20 | Flashcards | Generate deck with empty topic | Validation error shown | Error: "Please enter a topic." | ✅ Pass |
| TC-21 | Flashcards | Tap card to flip | Card rotates 180° showing answer | `rotation3DEffect` animation plays correctly | ✅ Pass |
| TC-22 | Flashcards | Tap "Knew it!" | Card stats updated, advance to next card | `knewItCount` incremented, index advances | ✅ Pass |
| TC-23 | Flashcards | Complete all cards in deck | Show session completion screen | Completion view with score circle appears | ✅ Pass |
| TC-24 | Analytics | View Progress tab with no data | Show empty state in charts | Bar chart shows zero-height bars | ✅ Pass |
| TC-25 | Analytics | Complete quiz → view Progress tab | Quiz count increments | `totalQuizzesTaken` updates in real time | ✅ Pass |
| TC-26 | Persistence | Kill and relaunch app | Data persists across launches | UserDefaults + JSON decode restores all data | ✅ Pass |
| TC-27 | Dashboard | View Home tab with no activity | "Getting started" empty state card shown | Welcome card visible with instructions | ✅ Pass |

---

### Bug Fixes and Iterations

#### Bug 1 — Missing `Subject.presets` member
**Error**: `type 'Subject' has no member 'presets'`
**Root cause**: `static let presets` was accidentally removed from `Subject` struct during Models.swift rewrite.
**Fix**: Re-added `static let presets: [Subject]` array to `Subject` struct.
**Iteration**: Build fail → fix → build pass (1 iteration).

---

#### Bug 2 — New Swift files not compiled by Xcode
**Error**: `cannot find 'LearningStore' in scope` / `cannot find type 'LearningStore' in scope`
**Root cause**: Files created on disk via code editor are not automatically added to Xcode project target. `project.pbxproj` must be manually updated with `PBXFileReference`, `PBXBuildFile`, and `PBXSourcesBuildPhase` entries.
**Fix**: Added all 13 new files to `project.pbxproj` using the established ID pattern (`SCSTDY0XX...`).
**Iteration**: Build fail → pbxproj edit → build pass (1 iteration per batch of new files).

---

#### Bug 3 — Duplicate `TypingDotsView` declaration
**Error**: `invalid redeclaration of 'TypingDotsView'`
**Root cause**: `TypingDotsView` was defined as a `private struct` in the original `AICoachView.swift` and again as a non-private `struct` in the new `AITutorView.swift`. Both files were compiled in the same module.
**Fix**: Renamed the declaration in `AICoachView.swift` to `_LegacyTypingDotsView` (unused legacy file pending deletion). The canonical definition in `AITutorView.swift` is used by both views.
**Iteration**: Build fail → rename → build pass (1 iteration).

---

#### Bug 4 — `QuizSession.score` computed property error
**Error**: Logic error in `zip` filter using incorrect `$0.element` syntax.
**Root cause**: `zip(questions, userAnswers)` produces `(QuizQuestion, Int)` tuples, not indexed sequences. Used wrong filter pattern.
**Fix**: Changed to `zip(questions, userAnswers).filter { question, answer in question.correctIndex == answer }.count`
**Iteration**: Logic review → fix before first build (caught during code review, 0 build failures).

---

#### Bug 5 — SDKROOT pulling macOS build target
**Error**: Multiple SwiftUI APIs (`navigationBarHidden`, `toolbarColorScheme`) unavailable on macOS.
**Root cause**: `SDKROOT = auto` in `project.pbxproj` caused Xcode 14.3.1 to attempt Mac Catalyst compilation.
**Fix**: Changed all 6 instances of `SDKROOT = auto` → `SDKROOT = iphoneos` and added `SUPPORTS_MACCATALYST = NO` to all build configurations.
**Iteration**: Multiple build failures → pbxproj edits → all macOS errors resolved.
