# Smart Study Companion — Project Context

## Project Identity

- **App name**: Smart Study Companion
- **Bundle ID**: `njjxzc.adu.cn.FinalProject`
- **Course**: iOS Application Development
- **Deadline**: July 1, 2026
- **Min deployment**: iOS 16.4
- **Swift version**: 5.0
- **Platform**: iPhone (SwiftUI, single target)
- **Developer**: Juan

---

## Practical Significance

University students consistently struggle with three interrelated problems:

1. **Unstructured study time** — students sit at a desk for hours but accomplish little due to distraction and no clear work/break boundaries.
2. **No visibility into learning habits** — students have no data on which subjects they actually spend time on vs. which they neglect.
3. **Lack of on-demand academic guidance** — getting help with a concept at 11 PM means waiting until the next day or searching scattered resources.

**Smart Study Companion** addresses all three. It provides:
- A Pomodoro timer that enforces focused work sessions and structured breaks, backed by cognitive science (Pomodoro Technique by Francesco Cirillo).
- Per-subject session tracking that auto-saves study time so students always know exactly where their hours went.
- An AI coaching chatbot (Groq + Llama-3) that answers concept questions, suggests study strategies, and motivates — available 24/7.
- A 7-day analytics view and streak counter that make progress visible and motivate consistency.

**Primary beneficiaries**: University students, especially those preparing for exams or managing multiple subjects simultaneously.

---

## Competitor Analysis

| App | Strength | Limitation |
|-----|----------|-----------|
| **Forest** | Beautiful timer, gamified focus | No subject tracking, no AI, no analytics |
| **Notion** | Flexible notes + task tracking | No timer, no AI coach, complex setup |
| **Anki** | Spaced repetition flashcards | Only for memorization, no session tracking |
| **MyStudyLife** | Timetable + task management | No Pomodoro, no AI, no real-time coaching |
| **Focusplan** | Pomodoro + basic stats | No AI, limited subject customisation |
| **ChatGPT app** | Powerful AI answers | No study session context, no timer, no tracking |

**How Smart Study Companion improves on all of them**: It is the only app that combines a Pomodoro timer, per-subject tracking, 7-day analytics, and a context-aware AI coach in a single cohesive dark-themed interface designed specifically for students.

---

## Module Structure

```
FinalProject/
├── FinalProjectApp.swift           App entry — @StateObject StudyStore injected as .environmentObject
├── MainTabView.swift               6-tab navigation shell
│
├── Theme/
│   └── StudyTheme.swift            Design tokens: colours, spacing, typography, StudyCard, GradientStudyCard
│
├── Models/
│   └── Models.swift                Subject, StudySession, PomodoroConfig, ChatMessage, Color(hex:)
│
├── Services/
│   └── StudyStore.swift            @MainActor ObservableObject — all persistence (UserDefaults JSON)
│                                   Computed stats: todayWorkMinutes, currentStreak, last7DaysMinutes,
│                                   minutesBySubjectToday, recentSessions
│
└── Features/
    ├── Dashboard/
    │   └── DashboardView.swift     Hero banner, daily goal progress bar, today's subjects, recent sessions
    │
    ├── Pomodoro/
    │   ├── PomodoroView.swift      Circular ring timer, mode selector, subject picker sheet, completion banner
    │   └── PomodoroViewModel.swift @MainActor state machine: work→shortBreak→longBreak, Timer, session save
    │
    ├── Subjects/
    │   ├── SubjectsView.swift      Subject list, swipe-to-delete, add/edit sheet with colour grid
    │   └── SubjectsViewModel.swift Draft state for add/edit sheet
    │
    ├── Analytics/
    │   └── AnalyticsView.swift     7-day bar chart (pure SwiftUI shapes), streak tile, subject breakdown bars
    │
    ├── AICoach/
    │   ├── AICoachView.swift       Chat interface, bubble layout, typing indicator, input bar
    │   └── AICoachViewModel.swift  Groq Llama-3 HTTP call, conversation history (last 6 messages), error handling
    │
    └── Settings/
        └── SettingsView.swift      Pomodoro duration steppers, daily goal slider, about section
```

---

## Data Models (`Models/Models.swift`)

### Subject
```swift
struct Subject: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String    // "#4A8EFF" format
    var emoji: String
    // var color: Color  — computed from colorHex
    static let presets: [Subject]   // 5 default subjects on first launch
    static let colorOptions: [String]  // 10 hex color choices
}
```

### StudySession
```swift
struct StudySession: Identifiable, Codable {
    var id: UUID
    var subjectId: UUID?        // nil = free study (no subject selected)
    var subjectName: String?    // denormalised for display without join
    var startDate: Date
    var durationMinutes: Int
    var sessionType: SessionType  // .work | .shortBreak | .longBreak
    // var isToday: Bool — Calendar.isDateInToday(startDate)
}
```

### PomodoroConfig
```swift
struct PomodoroConfig: Codable, Equatable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var longBreakAfterPomodoros: Int = 4
    var dailyGoalHours: Double = 4.0
    var autoStartBreaks: Bool = true
}
```

### ChatMessage
```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let role: String    // "user" or "assistant"
    let content: String
    let date: Date
}
```

---

## StudyStore — Persistence & Stats (`Services/StudyStore.swift`)

`StudyStore` is a `@MainActor final class ObservableObject` injected as `@EnvironmentObject` throughout the app.

### Persistence
All data stored in `UserDefaults` as JSON (via `JSONEncoder`/`JSONDecoder`):
- `study.subjects` → `[Subject]`
- `study.sessions` → `[StudySession]` (capped at 90 days rolling)
- `study.config` → `PomodoroConfig`

On first launch: 5 preset subjects are seeded automatically.

### Key Computed Properties
| Property | Description |
|----------|-------------|
| `todayWorkMinutes: Int` | Sum of `.work` session minutes for today |
| `todayGoalProgress: Double` | 0.0–1.0 fraction of daily goal |
| `currentStreak: Int` | Consecutive days meeting daily goal (checks up to 90 days back) |
| `last7DaysMinutes: [(label: String, minutes: Int)]` | 7-element array for bar chart, index 0 = oldest |
| `minutesBySubjectToday: [(subject: Subject, minutes: Int)]` | Today's work sessions grouped by subject, sorted descending |
| `recentSessions: [StudySession]` | Last 10 work sessions |

---

## Pomodoro Timer (`Features/Pomodoro/`)

### TimerMode enum
```
.work       → colour: blue (#6194FF),  icon: brain.head.profile
.shortBreak → colour: green (#33C28F), icon: cup.and.saucer.fill
.longBreak  → colour: purple (#B370FF),icon: figure.walk
```

### PomodoroViewModel State Machine
```
States: isRunning, mode (TimerMode), timeRemaining, totalTime, completedPomodoros

start()    → isRunning=true, sessionStartDate=Date(), schedules Timer(1 second)
pause()    → isRunning=false, invalidates timer
tick()     → timeRemaining -= 1; at 0 → saveCurrentSession() → advance() → applyConfig()
skipToNext() → pause() → saveCurrentSession(skipped:true) → advance() → applyConfig()
resetCurrent() → pause() → timeRemaining=totalTime

advance() logic:
  .work      → completedPomodoros += 1
               completedPomodoros % longBreakAfterPomodoros == 0 → .longBreak
               else → .shortBreak
  .shortBreak/.longBreak → .work

applyConfig():
  Sets totalTime from config.workMinutes / shortBreakMinutes / longBreakMinutes
  Sets timeRemaining = totalTime
  If autoStartBreaks=true AND mode != .work → start()
```

### Session Auto-Save
`saveCurrentSession()` only saves if `mode == .work` AND `elapsed >= 1 minute`. Creates a `StudySession` with the selected subject and calls `store.addSession(_:)`.

### Display
- Timer shown as `"MM:SS"` format with `.monospacedDigit()` and `.contentTransition(.numericText())`
- Ring: `Circle().trim(from: 0, to: vm.progress)` rotated -90°, animated `.linear(duration: 1)`
- Ring stroke: 14pt, `.round` lineCap, mode's color

---

## AI Coach (`Features/AICoach/`)

### Architecture
```
AICoachViewModel (@MainActor ObservableObject)
  @Published messages: [ChatMessage]
  @Published inputText: String
  @Published isLoading: Bool

send(currentSubjectName:) async
  → append user message
  → clear inputText
  → callGroq(userMessage, subjectContext) async throws
  → append assistant reply
  → on error: append fallback message
```

### Groq API Integration
- **Endpoint**: `https://api.groq.com/openai/v1/chat/completions`
- **Model**: `llama3-70b-8192`
- **Auth**: `Bearer $GROQ_API_KEY` from `ProcessInfo.processInfo.environment["GROQ_API_KEY"]`
- **System prompt**: "You are a helpful, encouraging study coach... Keep responses under 180 words." + optional subject context injection
- **History**: last 6 messages sent for conversation continuity
- **Parameters**: `max_tokens: 350`, `temperature: 0.75`
- **Timeout**: 20 seconds
- **API key absent**: returns instructional message, does NOT crash
- **Error handling**: network failure shows fallback message in chat bubble

### Chat UI
- User bubbles: right-aligned, `StudyTheme.accent` background, black text
- Assistant bubbles: left-aligned, `StudyTheme.surface2` background, white text, brain icon avatar
- Typing indicator: 3 grey dots while `isLoading=true`
- Auto-scroll: `ScrollViewReader` + `.onChange(of: vm.messages.count)`
- Input bar: multi-line `TextField` (up to 4 lines) + send button disabled when empty or loading

---

## Analytics (`Features/Analytics/AnalyticsView.swift`)

### 7-Day Bar Chart
Built entirely with pure SwiftUI (no Charts framework, no third-party libraries):
- `GeometryReader` for responsive bar width: `(totalWidth - (count-1) × 8) / count`
- Bar height: proportional to `minutes / max(maxMins, goalMins + 1) × chartHeight(140)`
- Goal line: dashed `Path` at calculated Y offset using `StrokeStyle(dash: [5,3])`
- Today's bar uses `accentGradient`, past days use `accent.opacity(0.5)`

### Summary Tiles
Three tiles in HStack: current streak (flame icon), today's study time, subject count.

### Subject Breakdown
Horizontal bars from `store.minutesBySubjectToday`, scaled to the max subject's minutes.

---

## Design System (`Theme/StudyTheme.swift`)

### Colours
| Token | Hex | Use |
|-------|-----|-----|
| `background` | `#0D0F1E` | All screen backgrounds |
| `surface` | `#1A1C33` | Cards |
| `surface2` | `#262A45` | Elevated elements, input fields |
| `accent` | `#6194FF` | Primary interactive, focus timer |
| `focusColor` | `#6194FF` | Work mode ring |
| `shortBreakColor` | `#33C28F` | Short break ring |
| `longBreakColor` | `#B370FF` | Long break ring |
| `success` | `#33C875` | Goal complete |
| `warning` | `#FFC433` | Chart goal line |
| `secondaryText` | `#8B8EB3` | Subtitles, hints |

### Gradients
- `accentGradient`: blue → purple (topLeading → bottomTrailing)
- `focusGradient`: deep blue → dark blue (used on Dashboard hero banner)

### Reusable Views
- `StudyCard<Content>`: dark surface card, rounded 20pt corners, shadow, optional title
- `GradientStudyCard<Content>`: gradient-filled card (used for hero banners)
- `PrimaryStudyButtonStyle`: gradient-filled button, white text

### Typography (all `.rounded` design)
| Token | Size/Weight |
|-------|------------|
| `hero` | largeTitle, bold |
| `metric` | 56pt, black |
| `title` | title2, bold |
| `cardTitle` | title3, semibold |
| `subtitle` | subheadline, semibold |
| `body` | body |
| `caption` | caption |
| `tiny` | caption2, medium |

---

## Navigation (`MainTabView.swift`)

```swift
TabView(selection: $selectedTab) {
    DashboardView()     .tabItem { Label("Home",     "house.fill" / "house") }          .tag(0)
    PomodoroView()      .tabItem { Label("Focus",    "timer.circle.fill" / "timer") }   .tag(1)
    SubjectsView()      .tabItem { Label("Subjects", "books.vertical.fill" / ...) }     .tag(2)
    AICoachView()       .tabItem { Label("Coach",    "brain.head.profile" / "brain") }  .tag(3)
    AnalyticsView()     .tabItem { Label("Progress", "chart.bar.fill" / "chart.bar") }  .tag(4)
    SettingsView()      .tabItem { Label("Settings", "gearshape.fill") }                .tag(5)
}
.tint(StudyTheme.accent)
.preferredColorScheme(.dark)
```

`PomodoroView` is initialised with `store` directly (needed for `PomodoroViewModel` init). All other views access store via `@EnvironmentObject`.

---

## App Entry Point (`FinalProjectApp.swift`)

```swift
@main
struct FinalProjectApp: App {
    @StateObject private var store = StudyStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
```

`StudyStore` is created once and injected as environment object for the entire view hierarchy. `PomodoroViewModel` is created with `@StateObject` inside `PomodoroView` — NOT shared, because timer state is local to that screen.

---

## AI Agent Architecture (for Report)

The app was developed using multiple AI agents with distinct roles:

### Agent 1 — Architecture & Foundation Agent
- **Role**: Designed the overall app architecture, data models, and design system
- **Skills**: Swift architecture design, MVVM pattern, data modelling
- **Output**: `Models.swift`, `StudyTheme.swift`, `StudyStore.swift`, `FinalProjectApp.swift`
- **Ticket**: "Define domain models, persistence layer, and design tokens before any UI work"

### Agent 2 — Pomodoro Timer Agent
- **Role**: Implemented the core Pomodoro state machine and timer UI
- **Skills**: Swift `Timer`, SwiftUI animations, state machine design
- **Output**: `PomodoroViewModel.swift`, `PomodoroView.swift`
- **Ticket**: "Build work/break cycle state machine with auto-advance, session auto-save, and circular ring UI"
- **Collaboration**: Reads `store.config` for durations; calls `store.addSession()` on completion

### Agent 3 — AI Coach Integration Agent
- **Role**: Integrated Groq API for the study coaching chatbot
- **Skills**: URLSession async/await, Groq REST API, chat UI patterns
- **Output**: `AICoachViewModel.swift`, `AICoachView.swift`
- **Ticket**: "Implement Groq Llama-3 chat with conversation history, subject context injection, and graceful error handling"
- **Collaboration**: Reads `store.subjects.first?.name` for current subject context

### Agent 4 — Analytics & UI Agent
- **Role**: Built the analytics charts and all remaining feature screens
- **Skills**: SwiftUI GeometryReader, pure-code bar charts, dashboard design
- **Output**: `AnalyticsView.swift`, `DashboardView.swift`, `SubjectsView.swift`, `SettingsView.swift`
- **Ticket**: "Build 7-day bar chart without external libraries; dashboard hero with goal progress"
- **Collaboration**: Reads all computed stats from `StudyStore`

### Agent Workflow
```
Agent 1 (Foundation) → produces Models + StudyStore
    ↓
Agent 2 (Timer) + Agent 3 (AI) → parallel, both depend only on Agent 1 output
    ↓
Agent 4 (UI/Analytics) → depends on all of the above
    ↓
Integration: MainTabView wires all features together
```

---

## Testing

### Test Cases

| # | Feature | Test | Expected | Actual |
|---|---------|------|----------|--------|
| 1 | Timer tick | Start timer, wait 1s | timeRemaining decreases by 1 | ✅ Pass |
| 2 | Timer mode advance | Complete work session | mode → .shortBreak | ✅ Pass |
| 3 | Long break after 4 | Complete 4 work sessions | mode → .longBreak on 4th | ✅ Pass |
| 4 | Session save | Complete 1-min work session | Session appears in recentSessions | ✅ Pass |
| 5 | Streak calculation | Study for goal each day 3 days | currentStreak == 3 | ✅ Pass |
| 6 | Subject add | Add subject with emoji+color | Appears in list with correct colour | ✅ Pass |
| 7 | Subject delete | Swipe-delete subject | Subject removed from list | ✅ Pass |
| 8 | Persistence | Kill & relaunch app | Subjects and sessions restored | ✅ Pass |
| 9 | AI Coach no key | Send message without GROQ_API_KEY | Shows instructional message, no crash | ✅ Pass |
| 10 | Bar chart | Add sessions across 3 days | Bars appear for correct days | ✅ Pass |
| 11 | Daily goal progress | Study half of goal | Progress bar shows ~50% | ✅ Pass |
| 12 | Session type filter | Add shortBreak session | Does NOT appear in todayWorkMinutes | ✅ Pass |

### Bug Fixes During Development

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `PomodoroConfig` doesn't conform to Equatable | `onChange(of:)` requires `Equatable` | Added `: Equatable` conformance to `PomodoroConfig` |
| `cannot convert String to UUID` | Passed `"typing"` String to `scrollTo(_:anchor:)` which uses generic `Hashable` — UUID mismatch | Changed to `scrollTo(lastId, anchor:)` only when `messages.last?.id` exists |
| `reference to captured var 'self' in concurrently-executing code` | Mutable `self` captured in Timer closure launching `Task` | Added `guard let self` + `[self]` capture list in `Task { @MainActor [self] in }` |

### Build Verification
```bash
xcodebuild -project FinalProject.xcodeproj \
           -scheme FinalProject \
           -destination 'generic/platform=iOS Simulator' \
           build
# Result: ** BUILD SUCCEEDED **
```

---

## Key Design Decisions

1. **Single target, no SPM modules** — simpler structure than reference app; all files in one target reduces Xcode configuration overhead for a student project.
2. **UserDefaults + JSON over CoreData/SwiftData** — sufficient for session/subject data volume; no schema migrations needed; simpler to debug and reset during development.
3. **`@EnvironmentObject` for StudyStore** — avoids prop-drilling through 3+ view levels; StudyStore is the single source of truth for all persistent state.
4. **`@StateObject` for PomodoroViewModel inside PomodoroView** — timer state is ephemeral and view-local; does not need to survive tab switches or be shared.
5. **Pure SwiftUI bar chart (no Charts.framework)** — works on iOS 16.4 without importing Charts (which requires iOS 16+). GeometryReader gives full control over bar proportions and goal line overlay.
6. **Context injection in Groq system prompt** — current subject is appended to the system prompt dynamically so the AI gives relevant subject-specific advice without requiring any extra API calls.
7. **Conversation history capped at 6 messages** — keeps API request size small while maintaining conversational continuity across 3 exchanges.
8. **Session deduplication via durationMinutes >= 1** — prevents zero-duration ghost sessions from appearing if the user starts and immediately skips.
9. **90-day session retention** — enough history for meaningful analytics without unbounded UserDefaults growth.
10. **`autoStartBreaks`** — respects the Pomodoro Technique's intent; user can disable if they prefer manual control.

---

## Local Setup

```bash
cd /Users/JujuOnTheBeat/Documents/FinalProject
open FinalProject.xcodeproj
# Scheme: FinalProject
# Destination: iPhone Simulator or real device
```

To enable AI Coach:
1. Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
2. Add: `GROQ_API_KEY` = `<your_groq_api_key>`
3. Get API key from: https://console.groq.com

Build command:
```bash
xcodebuild -project FinalProject.xcodeproj \
           -scheme FinalProject \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           -configuration Debug build
```

---

## File Reference

| File | Lines | Purpose |
|------|-------|---------|
| `Theme/StudyTheme.swift` | 119 | Design system |
| `Models/Models.swift` | 92 | Domain models |
| `Services/StudyStore.swift` | 138 | Persistence + computed stats |
| `MainTabView.swift` | 48 | Tab navigation |
| `Features/Dashboard/DashboardView.swift` | 181 | Home screen |
| `Features/Pomodoro/PomodoroView.swift` | 277 | Timer UI |
| `Features/Pomodoro/PomodoroViewModel.swift` | 151 | Timer state machine |
| `Features/Subjects/SubjectsView.swift` | 202 | Subject management |
| `Features/Subjects/SubjectsViewModel.swift` | 47 | Subject form state |
| `Features/Analytics/AnalyticsView.swift` | 207 | Charts + stats |
| `Features/AICoach/AICoachView.swift` | 176 | Chat UI |
| `Features/AICoach/AICoachViewModel.swift` | 88 | Groq API + chat logic |
| `Features/Settings/SettingsView.swift` | 110 | App configuration |
| **Total** | **1,836** | |
