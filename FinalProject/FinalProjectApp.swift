import SwiftUI

@main
struct FinalProjectApp: App {
    /// New store — used by all new feature views
    @StateObject private var learningStore = LearningStore()

    /// Legacy store — kept until old views (Pomodoro, Subjects) are removed in Step 7
    @StateObject private var studyStore = StudyStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(learningStore)
                .environmentObject(studyStore)
                .preferredColorScheme(.dark)
        }
    }
}
