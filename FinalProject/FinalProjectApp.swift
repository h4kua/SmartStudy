import SwiftUI

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
