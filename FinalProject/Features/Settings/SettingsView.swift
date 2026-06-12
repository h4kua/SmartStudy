import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36))
                            .foregroundStyle(StudyTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Study Companion")
                                .font(StudyFont.cardTitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Text("Version 1.0")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                    }
                    .listRowBackground(StudyTheme.surface)
                }

                Section(header: Text("Pomodoro Timer")) {
                    stepperRow(
                        label: "Focus Duration",
                        value: $store.config.workMinutes,
                        range: 5...90, step: 5,
                        unit: "min"
                    )
                    stepperRow(
                        label: "Short Break",
                        value: $store.config.shortBreakMinutes,
                        range: 1...30, step: 1,
                        unit: "min"
                    )
                    stepperRow(
                        label: "Long Break",
                        value: $store.config.longBreakMinutes,
                        range: 5...60, step: 5,
                        unit: "min"
                    )
                    stepperRow(
                        label: "Long Break After",
                        value: $store.config.longBreakAfterPomodoros,
                        range: 2...8, step: 1,
                        unit: "pomodoros"
                    )
                    Toggle("Auto-start Breaks", isOn: $store.config.autoStartBreaks)
                        .tint(StudyTheme.accent)
                }
                .listRowBackground(StudyTheme.surface)
                .onChange(of: store.config) { _ in store.saveConfig() }

                Section(header: Text("Daily Goal")) {
                    HStack {
                        Text("Study Goal")
                        Spacer()
                        Text("\(store.config.dailyGoalHours, specifier: "%.1f") hours")
                            .foregroundStyle(StudyTheme.accent)
                    }
                    Slider(
                        value: $store.config.dailyGoalHours,
                        in: 0.5...12, step: 0.5
                    )
                    .tint(StudyTheme.accent)
                }
                .listRowBackground(StudyTheme.surface)

                Section(header: Text("About")) {
                    infoRow(icon: "graduationcap.fill", label: "Course", value: "iOS App Development")
                    infoRow(icon: "calendar", label: "Deadline", value: "July 1, 2026")
                    infoRow(icon: "person.fill", label: "Developer", value: "Juan")
                }
                .listRowBackground(StudyTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(StudyTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .foregroundStyle(StudyTheme.accent)
                .frame(minWidth: 80, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(StudyTheme.accent)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(StudyTheme.secondaryText)
        }
    }
}
