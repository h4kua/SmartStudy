import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store:  LearningStore
    @EnvironmentObject var auth:   FirebaseAuthService
    @ObservedObject private var notif = NotificationService.shared
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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    appHeader
                    if auth.currentUser?.isAnonymous == true { guestBanner }
                    statsCard
                    notificationsCard
                    apiKeyCard
                    subjectsCard
                    dangerZone
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
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

    // MARK: - Guest banner

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
            Button("Sign In") { showSignOutConfirm = true } // signs out → back to auth
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

    // MARK: - App header

    private var appHeader: some View {
        VStack(spacing: StudySpacing.small) {
            ZStack {
                Circle()
                    .fill(StudyTheme.accentGradient)
                    .frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("AI Academic Mentor")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text("Version 1.0  ·  iOS Application Development")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
            // Signed-in user chip
            if let user = auth.currentUser {
                HStack(spacing: 6) {
                    Image(systemName: user.isAnonymous ? "person.fill.questionmark" : "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(user.isAnonymous ? StudyTheme.warning : StudyTheme.success)
                    Text(user.isAnonymous ? "Guest Account" : user.email)
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(StudyTheme.surface2)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, StudySpacing.large)
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        StudyCard(title: "Study Reminders") {
            VStack(spacing: StudySpacing.medium) {
                // Toggle row
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

                    // Time picker
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

    // MARK: - Stats snapshot

    private var statsCard: some View {
        StudyCard(title: "Your Progress") {
            VStack(spacing: StudySpacing.medium) {
                HStack(spacing: StudySpacing.medium) {
                    statCell(value: "\(store.totalQuizzesTaken)",
                             label: "Quizzes\nCompleted",
                             icon: "checkmark.circle.fill",
                             color: StudyTheme.accent)
                    statCell(value: "\(store.totalDecksCreated)",
                             label: "Flashcard\nDecks",
                             icon: "rectangle.on.rectangle.fill",
                             color: StudyTheme.longBreakColor)
                    statCell(value: "\(store.totalDocumentsAnalyzed)",
                             label: "Documents\nAnalyzed",
                             icon: "doc.text.fill",
                             color: StudyTheme.shortBreakColor)
                }

                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)

                HStack {
                    Label("\(store.currentStreak) day streak",
                          systemImage: "flame.fill")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(.orange)
                    Spacer()
                    if store.totalQuizzesTaken > 0 {
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StudyTheme.surface2)
        )
    }

    // MARK: - API Key info

    private var apiKeyCard: some View {
        StudyCard(title: "AI Configuration") {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                infoRow(icon: "cpu", label: "AI Provider", value: "Groq")
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                infoRow(icon: "brain", label: "Language Model", value: "Llama 3 70B")
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                infoRow(icon: "key.fill", label: "API Key", value: apiKeyStatus)

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
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(StudyTheme.warning.opacity(0.08))
                    )
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

    // MARK: - Subjects

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

    // MARK: - About / Danger zone

    private var dangerZone: some View {
        VStack(spacing: StudySpacing.medium) {
            StudyCard(title: "About") {
                VStack(alignment: .leading, spacing: StudySpacing.medium) {
                    infoRow(icon: "graduationcap.fill", label: "Course",    value: "iOS App Development")
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    infoRow(icon: "calendar",           label: "Deadline",  value: "July 1, 2026")
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    infoRow(icon: "person.fill",        label: "Developer", value: "Juan")
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
        // BUG FIX: delegate to store so keys stay in sync and state is properly persisted
        store.clearAllLearningData()
    }
}
