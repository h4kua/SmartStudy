import SwiftUI
import AVFoundation

// MARK: - Camera Preview (UIViewRepresentable)

/// A UIView whose layerClass is AVCaptureVideoPreviewLayer — no manual
/// frame updates needed; the layer always fills the view's bounds.
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class _View: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> _View {
        let view = _View()
        view.previewLayer.session     = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: _View, context: Context) {}
}

// MARK: - AI Sensor Visualization (Privacy Mode — no camera preview)

/// Abstract pulsing visualization shown when camera preview is hidden.
/// Gives the feeling of active AI analysis without showing the camera feed.
private struct AISensorView: View {
    let focusScore:  Double
    let focusState:  AttentionState
    let isActive:    Bool

    @State private var pulse1: Bool = false
    @State private var pulse2: Bool = false
    @State private var scanAngle: Double = 0

    var body: some View {
        ZStack {
            // Deep dark background
            Color.black.ignoresSafeArea()

            // Ambient color glow from current state
            RadialGradient(
                colors: [focusState.color.opacity(0.18), Color.black],
                center: .center,
                startRadius: 60,
                endRadius: 280
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: focusState.rawValue)

            if isActive {
                // Outer pulse ring 1
                Circle()
                    .stroke(focusState.color.opacity(pulse1 ? 0 : 0.25), lineWidth: 1.5)
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulse1 ? 1.3 : 1.0)
                    .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulse1)

                // Outer pulse ring 2 (offset timing)
                Circle()
                    .stroke(focusState.color.opacity(pulse2 ? 0 : 0.18), lineWidth: 1)
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse2 ? 1.4 : 0.9)
                    .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false).delay(0.6), value: pulse2)

                // Middle static ring (track)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Rotating scan arc
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(
                        AngularGradient(
                            colors: [focusState.color.opacity(0), focusState.color.opacity(0.9)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(scanAngle))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: scanAngle)

                // Inner hexagonal "brain chip" dots
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        let angle = Double(i) * 45.0
                        Circle()
                            .fill(focusState.color.opacity(0.55))
                            .frame(width: 5, height: 5)
                            .offset(
                                x: cos(angle * .pi / 180) * 72,
                                y: sin(angle * .pi / 180) * 72
                            )
                    }
                }

                // Diagonal crosshair lines (very faint)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: -80))
                    path.addLine(to: CGPoint(x: 0, y: 80))
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 160, height: 160)

                Path { path in
                    path.move(to: CGPoint(x: -80, y: 0))
                    path.addLine(to: CGPoint(x: 80, y: 0))
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 160, height: 160)

                // Center core
                ZStack {
                    Circle()
                        .fill(focusState.color.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Circle()
                        .fill(focusState.color.opacity(0.20))
                        .frame(width: 60, height: 60)
                    Circle()
                        .fill(focusState.color.opacity(0.35))
                        .frame(width: 36, height: 36)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(focusState.color)
                }
                .animation(.easeInOut(duration: 0.6), value: focusState.rawValue)

                // "AI ANALYZING" label
                VStack(spacing: 4) {
                    Spacer().frame(height: 170)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(focusState.color)
                            .frame(width: 5, height: 5)
                            .opacity(pulse1 ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse1)
                        Text("AI ANALYZING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(focusState.color.opacity(0.7))
                    }
                }
            } else {
                // Inactive — just show idle state
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 2)
                        .frame(width: 200, height: 200)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.20))
                }
            }
        }
        .onAppear {
            pulse1 = true
            pulse2 = true
            scanAngle = 360
        }
    }
}

// MARK: - FocusSessionView

struct FocusSessionView: View {
    @StateObject private var vm = FocusSessionViewModel()
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss

    /// Persisted preference: hide camera preview and show AI visualization instead.
    @AppStorage("focus.hideCameraPreview") private var hideCameraPreview: Bool = false
    @State private var drowsyPulse: Bool = false

    var body: some View {
        ZStack {
            if hideCameraPreview {
                // ── AI Sensor Mode — no camera feed shown ──────────
                AISensorView(
                    focusScore: vm.focusScore,
                    focusState: vm.focusState,
                    isActive:   vm.isActive
                )
            } else {
                // ── 1. Camera preview (full screen) ───────────────
                Color.black.ignoresSafeArea()
                CameraPreviewView(session: vm.cameraService.session)
                    .ignoresSafeArea()
                    .opacity(vm.isActive ? 1 : 0.3)
            }

            // ── Dark gradient overlay (both modes) ──────────────
            LinearGradient(
                colors: [
                    Color.black.opacity(0.60),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.70),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── UI overlay ──────────────────────────────────────
            VStack(spacing: 0) {
                topBar
                Spacer()

                if vm.permission == .denied {
                    permissionDeniedCard
                } else if !vm.isActive {
                    startCard
                } else {
                    focusPanel
                }

                Spacer()
                bottomBar
            }
            .padding(.horizontal, StudySpacing.large)

            // ── Drowsiness alert overlay (NEW) ──────────────────
            if vm.isActive && vm.focusState == .drowsy {
                drowsinessAlertOverlay
                    .transition(.opacity)
            }

            // ── Away warning overlay ─────────────────────────────
            if vm.showAwayWarning {
                awayWarningOverlay
            }

            // ── Session summary overlay ──────────────────────────
            if vm.showSummary {
                sessionSummaryOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { vm.stop() }
        // Log focus time to store when session summary appears
        .onChange(of: vm.showSummary) { showing in
            if showing {
                store.logFocusSession(durationSeconds: vm.stats.totalSeconds)
            }
        }
        // Animate drowsiness pulse when entering/leaving drowsy state
        .onChange(of: vm.focusState) { state in
            withAnimation(.easeInOut(duration: 0.3)) {
                drowsyPulse = (state == .drowsy)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.80))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Center — LIVE badge or title
            if vm.isActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(StudyTheme.danger)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(StudyFont.tiny)
                        .foregroundStyle(.white.opacity(0.90))
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            } else {
                Text("Focus Monitor")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            HStack(spacing: 8) {
                // Camera preview toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hideCameraPreview.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: hideCameraPreview ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hideCameraPreview ? .white.opacity(0.40) : .white.opacity(0.80))
                        .frame(width: 36, height: 36)
                        .background(hideCameraPreview
                                    ? Color.white.opacity(0.08)
                                    : Color.white.opacity(0.18))
                        .clipShape(Circle())
                }

                // Voice toggle + speaking indicator
                Button { vm.toggleVoice() } label: {
                    ZStack {
                        Circle()
                            .fill(vm.voiceEnabled
                                  ? (vm.isSpeaking
                                     ? StudyTheme.accent.opacity(0.50)
                                     : Color.white.opacity(0.18))
                                  : Color.white.opacity(0.08))
                            .frame(width: 36, height: 36)

                        Image(systemName: vm.voiceEnabled
                              ? (vm.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                              : "speaker.slash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(vm.voiceEnabled ? .white : .white.opacity(0.40))
                    }
                }
            }
        }
        .padding(.top, StudySpacing.large)
    }

    // MARK: - Start Card

    private var startCard: some View {
        VStack(spacing: StudySpacing.large) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 90, height: 90)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("AI Focus Monitor")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Vision AI analyzes your attention, eye openness,\nand head pose to keep you focused.")
                    .font(StudyFont.caption)
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                featurePill(icon: "eye.fill",          text: "Eye\nTracking")
                featurePill(icon: "person.fill",       text: "Head\nPose")
                featurePill(icon: "chart.bar.fill",    text: "Focus\nScore")
                featurePill(icon: "speaker.wave.2.fill", text: "Voice\nCoach")
            }

            // Privacy mode toggle right on start card
            HStack(spacing: 8) {
                Image(systemName: hideCameraPreview ? "eye.slash" : "video.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(StudyTheme.accent.opacity(0.8))
                Toggle("Hide camera preview", isOn: $hideCameraPreview)
                    .font(StudyFont.tiny)
                    .foregroundStyle(.white.opacity(0.70))
                    .tint(StudyTheme.accent)
            }
            .padding(.horizontal, StudySpacing.medium)

            Button {
                Task { await vm.requestAndStart() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                        .font(StudyFont.subtitle)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(StudyTheme.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(StudySpacing.large)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(StudyTheme.accent)
            Text(text)
                .font(StudyFont.tiny)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Focus Panel (active session)

    private var focusPanel: some View {
        VStack(spacing: StudySpacing.large) {

            // State badge
            stateBadge

            // Score ring
            scoreRing

            // Metric row
            metricRow

            // Voice status / message
            VStack(spacing: 6) {
                if vm.isSpeaking {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(StudyTheme.accent)
                        Text("Voice Coach speaking…")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.accent)
                    }
                    .transition(.opacity)
                } else {
                    Text(vm.focusState.message)
                        .font(StudyFont.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: vm.isSpeaking)
            .animation(.easeInOut(duration: 0.4),  value: vm.focusState.rawValue)
        }
    }

    // State Badge
    private var stateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.focusState.icon)
                .font(.system(size: 14, weight: .semibold))
            Text(vm.focusState.rawValue.uppercased())
                .font(StudyFont.tiny)
                .fontWeight(.bold)
                .tracking(1.2)
        }
        .foregroundStyle(vm.focusState.color)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(vm.focusState.color.opacity(0.18))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(vm.focusState.color.opacity(0.4), lineWidth: 1))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.focusState.rawValue)
    }

    // Score Ring
    private var scoreRing: some View {
        ZStack {
            // Glow
            Circle()
                .fill(vm.focusState.color.opacity(0.12))
                .frame(width: 185, height: 185)
                .blur(radius: 20)

            // Track
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 12)
                .frame(width: 160, height: 160)

            // Progress arc
            Circle()
                .trim(from: 0, to: vm.focusScore / 100.0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            vm.focusState.color.opacity(0.5),
                            vm.focusState.color,
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: vm.focusScore)

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(vm.focusScore))")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("Focus")
                    .font(StudyFont.tiny)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // Metric row (eye, head, time)
    private var metricRow: some View {
        HStack(spacing: 0) {
            metricChip(
                icon: "eye.fill",
                label: "Eyes",
                value: eyeLabel,
                color: eyeColor
            )
            divider
            metricChip(
                icon: "person.fill",
                label: "Head",
                value: headLabel,
                color: headColor
            )
            divider
            metricChip(
                icon: "timer",
                label: "Focused",
                value: vm.stats.focusedTimeString,
                color: StudyTheme.success
            )
        }
        .padding(.vertical, StudySpacing.medium)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 34)
    }

    private func metricChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
    }

    // Eye helpers
    private var eyeLabel: String {
        switch vm.focusState {
        case .drowsy:  return "Drowsy"
        case .away:    return "—"
        default:       return "Open"
        }
    }

    private var eyeColor: Color {
        vm.focusState == .drowsy ? StudyTheme.warning : StudyTheme.success
    }

    // Head helpers
    private var headLabel: String {
        switch vm.focusState {
        case .distracted: return "Away"
        case .away:       return "—"
        default:          return "Aligned"
        }
    }

    private var headColor: Color {
        vm.focusState == .distracted ? StudyTheme.warning : StudyTheme.success
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: StudySpacing.large) {
            if vm.isActive {
                // Session avg score
                VStack(spacing: 2) {
                    Text("Avg Score")
                        .font(StudyFont.tiny)
                        .foregroundStyle(.white.opacity(0.50))
                    Text("\(Int(vm.stats.avgScore))%")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Stop button
                Button {
                    vm.stop()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("End Session")
                            .font(StudyFont.subtitle)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(StudyTheme.danger.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(StudyTheme.danger.opacity(0.5), lineWidth: 1))
                }

                // Focus %
                VStack(spacing: 2) {
                    Text("Focus %")
                        .font(StudyFont.tiny)
                        .foregroundStyle(.white.opacity(0.50))
                    Text("\(Int(vm.stats.focusedPercent))%")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.bottom, StudySpacing.xxLarge)
    }

    // MARK: - Drowsiness Alert Overlay

    /// Subtle amber pulsing overlay shown when drowsy state is detected.
    /// Non-blocking — just a visual reminder. Voice coach also speaks.
    private var drowsinessAlertOverlay: some View {
        ZStack {
            // Pulsing amber glow from top (mimics "screen flash" without obscuring content)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        StudyTheme.warning.opacity(drowsyPulse ? 0.45 : 0.15),
                        Color.clear
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 160)
                .ignoresSafeArea(edges: .top)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: drowsyPulse
                )
                Spacer()

                // Pulsing amber glow from bottom
                LinearGradient(
                    colors: [
                        Color.clear,
                        StudyTheme.warning.opacity(drowsyPulse ? 0.30 : 0.08)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 120)
                .ignoresSafeArea(edges: .bottom)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.15),
                    value: drowsyPulse
                )
            }

            // Drowsy warning banner at top-center
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("DROWSINESS DETECTED")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.0)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(StudyTheme.warning)
                        .shadow(color: StudyTheme.warning.opacity(0.5), radius: 12, y: 4)
                )
                .opacity(drowsyPulse ? 1 : 0.6)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: drowsyPulse)
                .padding(.top, 60)
                Spacer()
            }
        }
        .allowsHitTesting(false) // don't block taps on underlying UI
    }

    // MARK: - Away Warning Overlay

    private var awayWarningOverlay: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            VStack(spacing: StudySpacing.large) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(StudyTheme.warning)

                Text("Are you still there?")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("You've been away from your desk\nfor \(vm.awaySeconds) seconds.")
                    .font(StudyFont.body)
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)

                Button {
                    vm.showAwayWarning = false
                } label: {
                    Text("I'm back!")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(.white)
                        .frame(width: 180, height: 48)
                        .background(StudyTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(StudySpacing.xxLarge)
        }
        .transition(.opacity)
    }

    // MARK: - Session Summary Overlay

    private var sessionSummaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()

            VStack(spacing: StudySpacing.large) {
                ZStack {
                    Circle()
                        .fill(StudyTheme.success.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(StudyTheme.success)
                }

                Text("Session Complete")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Stats row
                HStack(spacing: 0) {
                    summaryStatCell(
                        value: "\(vm.stats.totalSeconds / 60)m",
                        label: "Duration",
                        color: StudyTheme.accent
                    )
                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 44)
                    summaryStatCell(
                        value: "\(Int(vm.stats.avgScore))%",
                        label: "Avg Score",
                        color: StudyTheme.success
                    )
                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 44)
                    summaryStatCell(
                        value: "\(Int(vm.stats.focusedPercent))%",
                        label: "Focused",
                        color: StudyTheme.warning
                    )
                }
                .padding(.vertical, StudySpacing.medium)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(vm.sessionSummary)
                    .font(StudyFont.body)
                    .foregroundStyle(.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    vm.dismissSummary()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 50)
                        .background(StudyTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(StudySpacing.xxLarge)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.4), value: vm.showSummary)
    }

    private func summaryStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Permission Denied Card

    private var permissionDeniedCard: some View {
        VStack(spacing: StudySpacing.medium) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(StudyTheme.danger)
            Text("Camera Access Needed")
                .font(StudyFont.subtitle)
                .foregroundStyle(.white)
            Text("Enable camera in Settings → AI Academic Mentor → Camera")
                .font(StudyFont.caption)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(StudyTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(StudySpacing.large)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
