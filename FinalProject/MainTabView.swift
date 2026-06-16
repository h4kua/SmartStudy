import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: LearningStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            DashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            AITutorView()
                .tabItem {
                    Label("Tutor", systemImage: selectedTab == 1 ? "brain.head.profile" : "brain")
                }
                .tag(1)

            DocumentAnalyzerView()
                .tabItem {
                    Label("Documents", systemImage: selectedTab == 2 ? "doc.text.fill" : "doc.text")
                }
                .tag(2)

            LearnHubView()
                .tabItem {
                    Label("Learn", systemImage: selectedTab == 3 ? "lightbulb.fill" : "lightbulb")
                }
                .tag(3)

            AnalyticsView()
                .tabItem {
                    Label("Progress", systemImage: selectedTab == 4 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(4)

        }
        .tint(StudyTheme.accent)
        .preferredColorScheme(.dark)
    }
}
