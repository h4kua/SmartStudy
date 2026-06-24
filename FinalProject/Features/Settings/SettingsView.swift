import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store:  LearningStore
    @EnvironmentObject var auth:   FirebaseAuthService
    @ObservedObject private var notif = NotificationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirm    = false
    @State private var showSignOutConfirm  = false
    @State private var showSubjectManager  = false

    // BUG FIX: initialise from stored values — not Date() — so DatePicker shows the saved time
    @State private var reminderTime: Date = {
        var comps = DateComponents()
        comps.hour   = NotificationService.shared.reminderHour
        comps.minute = NotificationService.shared.reminderMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    // Focus Monitor preferences (persisted via AppStorage)
    @AppStorage("focus.hideCameraPreview") private var hideCameraPreview: Bool = false
    @AppStorage("focus.voiceDefault")      private var voiceDefault: Bool      = true

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    appHeader
                    if auth.currentUser?.isAnonymous == true { guestBanner }
                    statsCard
                    focusMonitorCard
                    notificationsCard
                    apiKeyCard
                    subjectsCard
                    dangerZone
                    Spacer().frame(height: StudySpacing.xxLarge)
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Clear Everything", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all quizzes, flashcard decks, and analyzed documents. This cannot be undone.")
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access the app.")
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: StudySpacing.small) {
            ZStack {
                Circle()
                    .fill(StudyTheme.accentGradient)
                    .frame(width: 76, height: 76)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("SmartStudy")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text("Version 1.0  ·  iOS App Development")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)

            if let user = auth.currentUser {
                HStack(spacing: 6) {
                    Image(systemName: user.isAnonymous ? "person.fill.questionmark" : "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(user.isAnonymous ? StudyTheme.warning : StudyTheme.success)
                    Text(user.isAnonymous ? "Guest Account" : (user.email))
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(StudyTheme.surface2)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, StudySpacing.medium)
    }

    // MARK: - Guest Banner

    private var guestBanner: some View {
        HStack(spacing: StudySpacing.medium) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 20))
                .foregroundStyle(StudyTheme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're in Guest Mode")
                    .font(StudyFont.caption).fontWeight(.semibold)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Sign in to save your progress across devices.")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
            Button("Sign In") { showSignOutConfirm = true }
                .font(StudyFont.tiny).fontWeight(.semibold)
                .foregroundStyle(StudyTheme.warning)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(StudyTheme.warning.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(StudySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StudyTheme.warning.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(StudyTheme.warning.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - Stats Snapshot

    private var statsCard: some View {
        StudyCard(title: "Your Progress") {
            VStack(spacing: StudySpacing.medium) {
                // Row 1 — quizzes, decks, docs
                HStack(spacing: StudySpacing.medium) {
                    statCell(value: "\(store.totalQuizzesTaken)",
                             label: "Quizzes",
                             icon: "checkmark.circle.fill",
                             color: StudyTheme.accent)
                    statCell(value: "\(store.totalDecksCreated)",
                             label: "Decks",
                             icon: "rectangle.on.rectangle.fill",
                             color: StudyTheme.longBreakColor)
                    statCell(value: "\(store.totalDocumentsAnalyzed)",
                             label: "Docs",
                             icon: "doc.text.fill",
                             color: StudyTheme.shortBreakColor)
                }

                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                // Row 2 — streak, avg, focus time
                HStack {
                    Label("\(store.currentStreak) day streak",
                          systemImage: "flame.fill")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(.orange)
                    Spacer()
                    if store.totalFocusMinutes > 0 {
                        Label("\(store.totalFocusMinutes)m focused",
                              systemImage: "brain.head.profile")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.accent)
                    } else if store.totalQuizzesTaken > 0 {
                        Text("Avg \(store.averageQuizScore.percentString)")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.accent)
                    }
                }
            }
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StudySpacing.small)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(StudyTheme.surface2))
    }

    // MARK: - Focus Monitor Card

    private var focusMonitorCard: some View {
        StudyCard(title: "Focus Monitor") {
            VStack(spacing: StudySpacing.medium) {
                // Hide camera preview toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("AI Sensor Mode", systemImage: "eye.slash.fill")
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("Hides camera preview — shows abstract AI visualization instead.")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $hideCameraPreview)
                        .tint(StudyTheme.accent)
                }

                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                // Voice coach default toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Voice Coach On by Default", systemImage: "speaker.wave.2.fill")
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("AI speaks focus reminders and encouragement during sessions.")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $voiceDefault)
                        .tint(StudyTheme.accent)
                        .onChange(of: voiceDefault) { _ in
                            // Preference is read by FocusSessionViewModel on next session start
                        }
                }

                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                // Stats row
                HStack(spacing: 0) {
                    focusStatPill(
                        icon: "timer",
                        value: store.totalFocusMinutes > 0
                            ? "\(store.totalFocusMinutes)m"
                            : "—",
                        label: "Total Focus"
                    )
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(width: 1, height: 36)
                    focusStatPill(
                        icon: "brain.head.profile",
                        value: hideCameraPreview ? "AI Mode" : "Camera",
                        label: "Display"
                    )
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(width: 1, height: 36)
                    focusStatPill(
                        icon: "speaker.wave.2.fill",
                        value: voiceDefault ? "On" : "Off",
                        label: "Voice"
                    )
                }
                .background(StudyTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func focusStatPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(StudyTheme.accent)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Notifications Card

    private var notificationsCard: some View {
        StudyCard(title: "Study Reminders") {
            VStack(spacing: StudySpacing.medium) {
                HStack {
                    Label("Daily Reminder", systemImage: "bell.fill")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.primaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { notif.reminderEnabled && notif.isAuthorized },
                        set: { val in
                            if val && !notif.isAuthorized {
                                Task { await notif.requestPermission() }
                            } else {
                                notif.setReminderEnabled(val)
                            }
                        }
                    ))
                    .tint(StudyTheme.accent)
                }

                if notif.reminderEnabled && notif.isAuthorized {
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(StudyTheme.accent)
                            .frame(width: 20)
                        Text("Reminder Time")
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                        Spacer()
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .onChange(of: reminderTime) { t in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: t)
                                notif.setReminderTime(hour: comps.hour ?? 19, minute: comps.minute ?? 0)
                            }
                    }
                }

                if !notif.isAuthorized {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(StudyTheme.warning)
                        Text("Enable notifications in iOS Settings to receive reminders.")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                }
            }
        }
        .task { await notif.checkStatus() }
    }

    // MARK: - AI Configuration Card

    private var apiKeyCard: some View {
        StudyCard(title: "AI Configuration") {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                infoRow(icon: "cpu",        label: "AI Provider",      value: "Groq")
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                infoRow(icon: "brain",      label: "Language Model",   value: "Llama 3 70B")
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                infoRow(icon: "network",    label: "Multi-Agent",      value: "CrewAI + FastAPI")
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                infoRow(icon: "key.fill",   label: "API Key",          value: apiKeyStatus)

                if !isAPIKeySet {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To enable AI features:")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.warning)
                        Text("Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables → Add GROQ_API_KEY")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(StudySpacing.medium)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StudyTheme.warning.opacity(0.08)))
                }
            }
        }
    }

    private var isAPIKeySet: Bool {
        !(ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? "").isEmpty
    }

    private var apiKeyStatus: String {
        isAPIKeySet ? "Configured ✓" : "Not Set"
    }

    // MARK: - Subjects Card

    private var subjectsCard: some View {
        StudyCard(title: "Subjects (\(store.subjects.count))") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.subjects.prefix(4)) { subject in
                    HStack(spacing: StudySpacing.medium) {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 10, height: 10)
                        Text(subject.emoji + " " + subject.name)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                        Spacer()
                    }
                    if subject.id != store.subjects.prefix(4).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
                if store.subjects.count > 4 {
                    Text("+\(store.subjects.count - 4) more")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.tertiaryText)
                }

                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                Button { showSubjectManager = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                        Text("Manage Subjects")
                            .font(StudyFont.caption)
                    }
                    .foregroundStyle(StudyTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
        }
        .sheet(isPresented: $showSubjectManager) {
            SubjectManagementView().environmentObject(store)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: StudySpacing.medium) {
            StudyCard(title: "About") {
                VStack(alignment: .leading, spacing: StudySpacing.medium) {
                    infoRow(icon: "graduationcap.fill", label: "Course",    value: "iOS App Development")
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    infoRow(icon: "calendar",           label: "Deadline",  value: "July 1, 2026")
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    infoRow(icon: "person.fill",        label: "Developer", value: "Juan")
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    infoRow(icon: "swift",              label: "Built with", value: "SwiftUI + Vision + GroqAI")
                }
            }

            Button {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: StudySpacing.small) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .font(StudyFont.subtitle)
                }
                .foregroundStyle(StudyTheme.warning)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(StudyTheme.warning.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(StudyTheme.warning.opacity(0.25), lineWidth: 1))
                )
            }

            Button {
                showClearConfirm = true
            } label: {
                HStack(spacing: StudySpacing.small) {
                    Image(systemName: "trash")
                    Text("Clear All Learning Data")
                        .font(StudyFont.subtitle)
                }
                .foregroundStyle(StudyTheme.danger)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(StudyTheme.danger.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(StudyTheme.danger.opacity(0.25), lineWidth: 1))
                )
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: StudySpacing.medium) {
            Image(systemName: icon)
                .foregroundStyle(StudyTheme.accent)
                .frame(width: 20)
            Text(label)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.primaryText)
            Spacer()
            Text(value)
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
        }
    }

    private func clearAllData() {
        store.clearAllLearningData()
    }
}
