import SwiftUI

struct PomodoroView: View {
    @EnvironmentObject var store: StudyStore
    @StateObject private var vm: PomodoroViewModel
    @State private var showSubjectPicker = false

    init(store: StudyStore) {
        _vm = StateObject(wrappedValue: PomodoroViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        modeSelector
                        timerRing
                        subjectBar
                        controlRow
                        sessionCountRow
                    }
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.vertical, StudySpacing.medium)
                    .padding(.bottom, StudySpacing.xxLarge)
                }

                // Completion banner
                if vm.showCompletionBanner {
                    completionBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .animation(.spring(response: 0.4, dampingFraction: 0.75),
                       value: vm.showCompletionBanner)
        }
        .sheet(isPresented: $showSubjectPicker) {
            subjectPickerSheet
        }
    }

    // MARK: - Mode selector

    private var modeSelector: some View {
        HStack(spacing: StudySpacing.small) {
            ForEach([TimerMode.work, .shortBreak, .longBreak], id: \.label) { m in
                Button {
                    guard !vm.isRunning else { return }
                    vm.mode = m
                    vm.resetCurrent()
                } label: {
                    Text(m.label)
                        .font(StudyFont.caption)
                        .foregroundStyle(vm.mode == m ? .black : StudyTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(vm.mode == m ? m.color : StudyTheme.surface2)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.top, StudySpacing.medium)
    }

    // MARK: - Timer ring

    private var timerRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(StudyTheme.surface2, lineWidth: 14)
                .frame(width: 260, height: 260)

            // Progress ring
            Circle()
                .trim(from: 0, to: vm.progress)
                .stroke(
                    vm.mode.color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: vm.progress)

            // Time label
            VStack(spacing: 4) {
                Text(vm.displayTime)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(vm.mode.label.uppercased())
                    .font(StudyFont.tiny)
                    .foregroundStyle(vm.mode.color)
                    .tracking(1.5)
            }
        }
        .padding(.vertical, StudySpacing.medium)
    }

    // MARK: - Subject bar

    private var subjectBar: some View {
        Button { showSubjectPicker = true } label: {
            HStack(spacing: StudySpacing.small) {
                if let sub = vm.selectedSubject {
                    Text(sub.emoji)
                        .font(.title3)
                    Text(sub.name)
                        .font(StudyFont.subtitle)
                        .foregroundStyle(sub.color)
                } else {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(StudyTheme.secondaryText)
                    Text("Select a subject")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            .padding(StudySpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StudyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: StudySpacing.medium) {
            // Reset
            Button { vm.resetCurrent() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 56, height: 56)
                    .background(StudyTheme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(StudyTheme.surfaceStroke, lineWidth: 1))
            }

            // Start / Pause
            Button { vm.toggleStartPause() } label: {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(vm.mode.color)
                    .clipShape(Circle())
                    .shadow(color: vm.mode.color.opacity(0.45), radius: 14, y: 5)
            }

            // Skip
            Button { vm.skipToNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 56, height: 56)
                    .background(StudyTheme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(StudyTheme.surfaceStroke, lineWidth: 1))
            }
        }
    }

    // MARK: - Session count

    private var sessionCountRow: some View {
        StudyCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pomodoros today")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                    Text("\(vm.completedPomodoros)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(vm.mode.color)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next long break")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                    let remaining = store.config.longBreakAfterPomodoros - (vm.completedPomodoros % store.config.longBreakAfterPomodoros)
                    Text("in \(remaining) pomodoro\(remaining == 1 ? "" : "s")")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                }
            }
        }
    }

    // MARK: - Completion banner

    private var completionBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: vm.mode.icon)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(vm.mode == .work ? "Focus session complete! 🎉" : "Break over — back to work!")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(vm.mode.color)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Subject picker sheet

    private var subjectPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    vm.selectedSubjectId = nil
                    showSubjectPicker = false
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(StudyTheme.secondaryText)
                        Text("No subject")
                            .foregroundStyle(StudyTheme.secondaryText)
                        Spacer()
                        if vm.selectedSubjectId == nil {
                            Image(systemName: "checkmark").foregroundStyle(StudyTheme.accent)
                        }
                    }
                }

                ForEach(store.subjects) { sub in
                    Button {
                        vm.selectedSubjectId = sub.id
                        showSubjectPicker = false
                    } label: {
                        HStack {
                            Text(sub.emoji).font(.title3)
                            Text(sub.name).foregroundStyle(StudyTheme.primaryText)
                            Spacer()
                            if vm.selectedSubjectId == sub.id {
                                Image(systemName: "checkmark").foregroundStyle(sub.color)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSubjectPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
