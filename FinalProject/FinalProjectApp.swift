import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate (required for Google Sign-In URL handling)

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 1. Configure Firebase FIRST
        FirebaseApp.configure()
        // 2. Start auth listener
        Task { @MainActor in
            FirebaseAuthService.shared.startListening()
        }
        // 3. Request notification permission
        Task { @MainActor in
            await NotificationService.shared.requestPermission()
        }
        return true
    }

    // Handle the Google Sign-In redirect URL
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Main App

@main
struct FinalProjectApp: App {

    // Attach AppDelegate so Firebase + GoogleSignIn URL handling works
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var learningStore = LearningStore()
    // Use ObservedObject on the shared singleton so SwiftUI tracks its @Published changes
    @ObservedObject private var authService = FirebaseAuthService.shared

    init() {
        StudyTheme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isSignedIn {
                    // Main app — fully authenticated
                    MainTabView()
                        .environmentObject(learningStore)
                        .environmentObject(authService)
                        .preferredColorScheme(.dark)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .opacity))
                } else {
                    // Not signed in — show login screen
                    AuthView()
                        .environmentObject(authService)
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: authService.isSignedIn)
        }
    }
}
