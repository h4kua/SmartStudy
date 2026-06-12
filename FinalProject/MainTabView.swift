import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: StudyStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            PomodoroView(store: store)
                .tabItem {
                    Label("Focus", systemImage: selectedTab == 1 ? "timer.circle.fill" : "timer")
                }
                .tag(1)

            SubjectsView()
                .tabItem {
                    Label("Subjects", systemImage: selectedTab == 2 ? "books.vertical.fill" : "books.vertical")
                }
                .tag(2)

            AICoachView()
                .tabItem {
                    Label("Coach", systemImage: selectedTab == 3 ? "brain.head.profile" : "brain")
                }
                .tag(3)

            AnalyticsView()
                .tabItem {
                    Label("Progress", systemImage: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(StudyTheme.accent)
        .preferredColorScheme(.dark)
    }
}
