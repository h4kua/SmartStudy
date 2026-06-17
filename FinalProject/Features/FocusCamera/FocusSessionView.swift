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

// MARK: - FocusSessionView

struct FocusSessionView: View {
    @StateObject private var vm = FocusSessionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ── 1. Camera preview (full screen) ──────────────────
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: vm.cameraService.session)
                .ignoresSafeArea()
                .opacity(vm.isActive ? 1 : 0.3)

            // ── 2. Dark gradient overlay ──────────────────────────
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.65),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── 3. UI overlay ─────────────────────────────────────
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

            // ── 4. Away warning overlay ───────────────────────────
            if vm.showAwayWarning {
                awayWarningOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { vm.stop() }
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
                        .opacity(vm.isSpeaking ? 1.0 : 0.85)
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
                Image(systemName: "camera.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Study Focus Monitor")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("AI watches your face to measure focus,\ndetect drowsiness, and track attention.")
                    .font(StudyFont.caption)
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 20) {
                featurePill(icon: "eye.fill",         text: "Eye Tracking")
                featurePill(icon: "person.fill",      text: "Head Pose")
                featurePill(icon: "chart.bar.fill",   text: "Focus Score")
            }

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
