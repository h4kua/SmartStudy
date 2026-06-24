import SwiftUI

// MARK: - TimerView

struct TimerView: View {
    @StateObject private var vm = TimerViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            StudyTheme.backgroundGradient.ignoresSafeArea()

            // Phase-color glow behind the ring
            Circle()
                .fill(vm.phase.color.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .animation(.easeInOut(duration: 0.6), value: vm.phase)

            VStack(spacing: 0) {
                // Phase selector chips
                phaseSelector
                    .padding(.top, StudySpacing.large)

                Spacer()

                // Main ring + time
                timerRing
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                Spacer()

                // Pomodoro cycle dots
                cycleDots
                    .padding(.bottom, StudySpacing.large)

                // Controls
                controls
                    .padding(.bottom, StudySpacing.xxLarge)
            }
            .padding(.horizontal, StudySpacing.large)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Phase Selector

    private var phaseSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimerPhase.allCases, id: \.self) { phase in
                Button { withAnimation(.spring(response: 0.4)) { vm.setPhase(phase) } } label: {
                    Text(phase.rawValue)
                        .font(StudyFont.tiny)
                        .fontWeight(vm.phase == phase ? .semibold : .regular)
                        .foregroundStyle(vm.phase == phase ? .white : StudyTheme.secondaryText)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            vm.phase == phase
                            ? AnyView(Capsule().fill(vm.phase.color))
                            : AnyView(Capsule().stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                        )
                }
            }
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(StudyTheme.surface2, lineWidth: 18)
                .frame(width: 220, height: 220)

            // Progress arc
            Circle()
                .trim(from: 0, to: vm.progress)
                .stroke(
                    vm.phase.color,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .shadow(color: vm.phase.color.opacity(0.5), radius: 12)
                .animation(.linear(duration: 1), value: vm.progress)

            // Center content
            VStack(spacing: 6) {
                Image(systemName: vm.phase.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(vm.phase.color)

                Text(vm.timeString)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: vm.timeString)

                Text(vm.phase.label.uppercased())
                    .font(StudyFont.tiny)
                    .foregroundStyle(vm.phase.color)
                    .tracking(1.5)
            }
        }
    }

    // MARK: - Cycle Dots

    private var cycleDots: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(vm.cycleDots[i] ? vm.phase.color : StudyTheme.surface2)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().stroke(vm.phase.color.opacity(0.4), lineWidth: 1)
                        )
                        .animation(.spring(response: 0.3), value: vm.pomodorosDone)
                }
            }
            Text(vm.totalToday == 0
                 ? "Start your first focus session"
                 : "\(vm.totalToday) session\(vm.totalToday == 1 ? "" : "s") completed today")
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: StudySpacing.large) {
            // Reset
            CircleControlButton(icon: "arrow.counterclockwise", size: 52) {
                vm.reset()
            }

            // Play / Pause — main button
            Button { vm.startPause() } label: {
                ZStack {
                    Circle()
                        .fill(vm.phase.color)
                        .frame(width: 80, height: 80)
                        .shadow(color: vm.phase.color.opacity(0.5), radius: 16, y: 6)
                    Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: vm.isRunning ? 0 : 2)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.isRunning)

            // Skip
            CircleControlButton(icon: "forward.end.fill", size: 52) {
                vm.skipPhase()
            }
        }
    }

}

// MARK: - Circle Control Button

private struct CircleControlButton: View {
    let icon:   String
    let size:   CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(StudyTheme.secondaryText)
                .frame(width: size, height: size)
                .background(StudyTheme.surface2)
                .clipShape(Circle())
                .overlay(Circle().stroke(StudyTheme.surfaceStroke, lineWidth: 1))
        }
    }
}
