import SwiftUI

@main
struct FinalProjectApp: App {
    @StateObject private var learningStore = LearningStore()

    init() {
        StudyTheme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(learningStore)
                .preferredColorScheme(.dark)
        }
    }
}
