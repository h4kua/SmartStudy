import SwiftUI

// MARK: - Auth Flow State

private enum AuthFlow: Equatable {
    case welcome
    case email
    case phone
    case otp(phoneNumber: String)
}

// MARK: - AuthView

struct AuthView: View {
    @EnvironmentObject var auth: FirebaseAuthService
    @State private var flow:    AuthFlow = .welcome
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            StudyTheme.backgroundGradient.ignoresSafeArea()

            // Aurora glow orbs
            auroraOrbs

            // Screen content
            Group {
                switch flow {
                case .welcome:
                    WelcomeScreen(flow: $flow)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                                removal:   .opacity))
                case .email:
                    EmailAuthScreen(flow: $flow)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal:   .move(edge: .trailing).combined(with: .opacity)))
                case .phone:
                    PhoneAuthScreen(flow: $flow)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal:   .move(edge: .trailing).combined(with: .opacity)))
                case .otp(let phone):
                    OTPScreen(flow: $flow, phoneNumber: phone)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal:   .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: flow)
        }
        .preferredColorScheme(.dark)
    }

    private var auroraOrbs: some View {
        ZStack {
            Circle()
                .fill(StudyTheme.accent.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -90, y: -180)
            Circle()
                .fill(StudyTheme.longBreakColor.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 110, y: 140)
        }
        .ignoresSafeArea()
    }
}

// =========================================================
// MARK: - 1. Welcome Screen
// =========================================================

private struct WelcomeScreen: View {
    @EnvironmentObject var auth: FirebaseAuthService
    @Binding var flow: AuthFlow
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: StudySpacing.medium) {
                ZStack {
                    Circle()
                        .fill(StudyTheme.accentGradient)
                        .frame(width: 88, height: 88)
                        .shadow(color: StudyTheme.accent.opacity(0.5), radius: 24, y: 8)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                VStack(spacing: 4) {
                    Text("AI Academic Mentor")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("Your smart study companion")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.45).delay(0.2), value: appeared)
            }

            Spacer()

            // Feature pills
            VStack(spacing: 10) {
                featureRow(icon: "sparkles",                 text: "AI-powered quiz & flashcard generation")
                featureRow(icon: "doc.text.magnifyingglass", text: "Instant document analysis")
                featureRow(icon: "chart.bar.fill",           text: "Track your progress & streaks")
                featureRow(icon: "mic.fill",                 text: "Voice-powered AI tutor")
            }
            .padding(.horizontal, StudySpacing.xxLarge)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.45).delay(0.3), value: appeared)

            Spacer()

            // Auth buttons
            VStack(spacing: StudySpacing.small) {
                // Google
                AuthProviderButton(
                    icon: "g.circle.fill",
                    label: "Continue with Google",
                    color: Color(red: 0.26, green: 0.52, blue: 0.96),
                    isLoading: auth.isLoading
                ) {
                    Task { await auth.signInWithGoogle() }
                }

                // Email
                AuthProviderButton(
                    icon: "envelope.fill",
                    label: "Continue with Email",
                    color: StudyTheme.accent,
                    isLoading: false
                ) {
                    withAnimation { flow = .email }
                }

                // Phone
                AuthProviderButton(
                    icon: "phone.fill",
                    label: "Continue with Phone",
                    color: StudyTheme.success,
                    isLoading: false
                ) {
                    withAnimation { flow = .phone }
                }

                if let err = auth.errorMessage {
                    Text(err)
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                        .transition(.opacity)
                }

                // Divider
                HStack {
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    Text("or").font(StudyFont.tiny).foregroundStyle(StudyTheme.tertiaryText)
                        .padding(.horizontal, 8)
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                }

                // Anonymous / Guest
                Button {
                    Task { await auth.signInAnonymously() }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading {
                            ProgressView().tint(StudyTheme.secondaryText).scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 16))
                        }
                        Text("Continue as Guest")
                            .font(StudyFont.caption)
                    }
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                    )
                }
                .disabled(auth.isLoading)

                Text("By continuing you agree to our Terms of Service.")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, StudySpacing.large)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.45).delay(0.4), value: appeared)

            Spacer().frame(height: StudySpacing.xxLarge)
        }
        .onAppear { appeared = true }
        .animation(.default, value: auth.errorMessage)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: StudySpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudyTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.secondaryText)
            Spacer()
        }
    }
}

// =========================================================
// MARK: - 2. Email Auth Screen
// =========================================================

private struct EmailAuthScreen: View {
    @EnvironmentObject var auth: FirebaseAuthService
    @Binding var flow: AuthFlow

    enum Mode { case login, create }
    @State private var mode:            Mode   = .login
    @State private var name:            String = ""
    @State private var email:           String = ""
    @State private var password:        String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword     = false
    @State private var showResetAlert   = false
    @State private var resetEmail       = ""
    @FocusState private var focused:    Field?

    enum Field: Hashable { case name, email, password, confirm }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                AuthHeader(title: mode == .login ? "Sign In" : "Create Account") {
                    withAnimation { flow = .welcome }
                }

                VStack(spacing: StudySpacing.large) {
                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab("Log In",         selected: mode == .login)  { mode = .login }
                        modeTab("Create Account", selected: mode == .create) { mode = .create }
                    }
                    .background(StudyTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Fields
                    VStack(spacing: StudySpacing.medium) {
                        if mode == .create {
                            AuthField(icon: "person.fill",
                                      placeholder: "Full Name",
                                      text: $name,
                                      secure: false,
                                      focused: $focused,
                                      field: .name,
                                      next: .email)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                    removal:   .move(edge: .top).combined(with: .opacity)))
                        }

                        AuthField(icon: "envelope.fill",
                                  placeholder: "Email Address",
                                  text: $email,
                                  secure: false,
                                  focused: $focused,
                                  field: .email,
                                  next: .password)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)

                        AuthField(icon: "lock.fill",
                                  placeholder: "Password",
                                  text: $password,
                                  secure: !showPassword,
                                  focused: $focused,
                                  field: .password,
                                  next: mode == .create ? .confirm : nil,
                                  trailingIcon: showPassword ? "eye.slash.fill" : "eye.fill",
                                  trailingAction: { showPassword.toggle() })
                        .textContentType(mode == .create ? .newPassword : .password)

                        if mode == .create {
                            AuthField(icon: "lock.fill",
                                      placeholder: "Confirm Password",
                                      text: $confirmPassword,
                                      secure: !showPassword,
                                      focused: $focused,
                                      field: .confirm,
                                      next: nil)
                            .textContentType(.newPassword)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal:   .move(edge: .bottom).combined(with: .opacity)))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mode)

                    // Error
                    if let err = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                            Text(err)
                                .font(StudyFont.tiny)
                        }
                        .foregroundStyle(StudyTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(StudySpacing.medium)
                        .background(StudyTheme.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Primary button
                    Button { handleSubmit() } label: {
                        HStack(spacing: 8) {
                            if auth.isLoading {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            }
                            Text(mode == .login ? "Sign In" : "Create Account")
                                .font(StudyFont.subtitle)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())
                    .disabled(auth.isLoading || !isFormValid)
                    .opacity(isFormValid ? 1 : 0.55)

                    // Forgot password
                    if mode == .login {
                        Button {
                            resetEmail = email
                            showResetAlert = true
                        } label: {
                            Text("Forgot password?")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.accent)
                        }
                    }
                }
                .padding(StudySpacing.large)
            }
        }
        .alert("Reset Password", isPresented: $showResetAlert) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            Button("Send Reset Link") {
                Task { await auth.resetPassword(email: resetEmail) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll send a password reset link to your email.")
        }
        .animation(.default, value: auth.errorMessage)
    }

    private func modeTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(StudyFont.caption)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? StudyTheme.primaryText : StudyTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selected
                    ? StudyTheme.surface.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    : nil
                )
                .animation(.spring(response: 0.3), value: selected)
        }
        .padding(3)
    }

    private var isFormValid: Bool {
        if mode == .login {
            return !email.isEmpty && password.count >= 6
        } else {
            return !name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
    }

    private func handleSubmit() {
        focused = nil
        Task {
            if mode == .login {
                await auth.signInWithEmail(email: email, password: password)
            } else {
                await auth.createAccount(name: name, email: email, password: password)
            }
        }
    }
}

// =========================================================
// MARK: - 3. Phone Auth Screen
// =========================================================

private struct PhoneAuthScreen: View {
    @EnvironmentObject var auth: FirebaseAuthService
    @Binding var flow: AuthFlow

    @State private var countryCode = "+62"
    @State private var phoneNumber = ""
    @FocusState private var focused: Bool

    private let countryCodes = [
        ("+62", "🇮🇩", "Indonesia"),
        ("+1",  "🇺🇸", "USA/Canada"),
        ("+44", "🇬🇧", "UK"),
        ("+65", "🇸🇬", "Singapore"),
        ("+60", "🇲🇾", "Malaysia"),
        ("+61", "🇦🇺", "Australia"),
        ("+81", "🇯🇵", "Japan"),
        ("+82", "🇰🇷", "Korea"),
        ("+86", "🇨🇳", "China"),
        ("+91", "🇮🇳", "India"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(title: "Phone Sign-In") {
                withAnimation { flow = .welcome }
            }

            VStack(spacing: StudySpacing.large) {
                // Instruction
                VStack(spacing: 6) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 36))
                        .foregroundStyle(StudyTheme.success)
                    Text("Enter your phone number")
                        .font(StudyFont.cardTitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("We'll send a one-time verification code via SMS.")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, StudySpacing.large)

                // Country picker + phone field
                VStack(spacing: StudySpacing.small) {
                    // Country code picker
                    Menu {
                        ForEach(countryCodes, id: \.0) { code, flag, name in
                            Button("\(flag) \(name)  \(code)") { countryCode = code }
                        }
                    } label: {
                        HStack {
                            Text(countryFlagFor(countryCode))
                                .font(.system(size: 22))
                            Text(countryCode)
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(StudyTheme.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal, StudySpacing.medium)
                        .frame(height: 52)
                        .background(StudyTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                    }

                    // Phone number input
                    HStack(spacing: StudySpacing.small) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(StudyTheme.accent)
                            .frame(width: 20)
                        TextField("8123 4567 89", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                            .focused($focused)
                    }
                    .padding(.horizontal, StudySpacing.medium)
                    .frame(height: 52)
                    .background(StudyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(focused ? StudyTheme.accent : StudyTheme.surfaceStroke, lineWidth: 1))
                    .animation(.easeInOut(duration: 0.2), value: focused)
                }

                // Error
                if let err = auth.errorMessage {
                    errorBanner(err)
                }

                // Send OTP button
                Button {
                    focused = false
                    let fullNumber = countryCode + phoneNumber.filter { $0.isNumber }
                    Task {
                        let sent = await auth.sendPhoneOTP(phoneNumber: fullNumber)
                        if sent { withAnimation { flow = .otp(phoneNumber: fullNumber) } }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading { ProgressView().tint(.white).scaleEffect(0.85) }
                        Text(auth.isLoading ? "Sending OTP…" : "Send OTP Code")
                            .font(StudyFont.subtitle)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(PrimaryStudyButtonStyle())
                .disabled(auth.isLoading || phoneNumber.filter(\.isNumber).count < 7)

                Text("Standard SMS rates may apply.")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.tertiaryText)
            }
            .padding(StudySpacing.large)

            Spacer()
        }
        .animation(.default, value: auth.errorMessage)
    }

    private func countryFlagFor(_ code: String) -> String {
        countryCodes.first(where: { $0.0 == code })?.1 ?? "🌐"
    }
}

// =========================================================
// MARK: - 4. OTP Screen
// =========================================================

private struct OTPScreen: View {
    @EnvironmentObject var auth: FirebaseAuthService
    @Binding var flow: AuthFlow
    let phoneNumber: String

    @State private var otpCode  = ""
    @State private var resent   = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(title: "Verify Phone") {
                withAnimation { flow = .phone }
            }

            VStack(spacing: StudySpacing.large) {
                // Instruction
                VStack(spacing: 6) {
                    Image(systemName: "message.badge.filled.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(StudyTheme.accent)
                    Text("Enter OTP Code")
                        .font(StudyFont.cardTitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("A 6-digit code was sent to\n\(phoneNumber)")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, StudySpacing.large)

                // OTP digit boxes
                OTPDigitBoxes(code: $otpCode, focused: $focused)
                    .onAppear { focused = true }

                // Error
                if let err = auth.errorMessage {
                    errorBanner(err)
                }

                // Verify button
                Button {
                    focused = false
                    Task { await auth.verifyPhoneOTP(code: otpCode) }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading { ProgressView().tint(.white).scaleEffect(0.85) }
                        Text(auth.isLoading ? "Verifying…" : "Verify & Sign In")
                            .font(StudyFont.subtitle)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(PrimaryStudyButtonStyle())
                .disabled(auth.isLoading || otpCode.count < 6)
                .opacity(otpCode.count == 6 ? 1 : 0.55)

                // Resend
                Button {
                    otpCode = ""
                    resent  = false
                    Task {
                        let sent = await auth.sendPhoneOTP(phoneNumber: phoneNumber)
                        if sent { resent = true }
                    }
                } label: {
                    Text(resent ? "✓ Code resent!" : "Resend OTP code")
                        .font(StudyFont.caption)
                        .foregroundStyle(resent ? StudyTheme.success : StudyTheme.accent)
                }
                .disabled(auth.isLoading)
            }
            .padding(StudySpacing.large)

            Spacer()
        }
        .animation(.default, value: auth.errorMessage)
        .onChange(of: otpCode) { _ in
            // Auto-submit when 6 digits entered
            if otpCode.count == 6 && !auth.isLoading {
                focused = false
                Task { await auth.verifyPhoneOTP(code: otpCode) }
            }
        }
    }
}

// =========================================================
// MARK: - OTP Digit Boxes Component
// =========================================================

private struct OTPDigitBoxes: View {
    @Binding var code: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            // Hidden text field that captures keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(focused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { val in
                    // Limit to 6 numeric digits
                    let filtered = val.filter(\.isNumber)
                    if filtered != val || val.count > 6 {
                        code = String(filtered.prefix(6))
                    }
                }

            // Visual boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { idx in
                    let digit = code.count > idx
                        ? String(code[code.index(code.startIndex, offsetBy: idx)])
                        : ""
                    let isActive = code.count == idx

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(digit.isEmpty ? StudyTheme.surface : StudyTheme.accent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isActive ? StudyTheme.accent : (digit.isEmpty ? StudyTheme.surfaceStroke : StudyTheme.accent.opacity(0.5)),
                                            lineWidth: isActive ? 2 : 1)
                            )
                            .frame(width: 46, height: 56)
                            .animation(.easeInOut(duration: 0.15), value: code.count)

                        Text(digit)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(StudyTheme.primaryText)

                        // Cursor blink when active
                        if isActive {
                            Rectangle()
                                .fill(StudyTheme.accent)
                                .frame(width: 2, height: 24)
                                .opacity(0.8)
                        }
                    }
                    .onTapGesture { focused.wrappedValue = true }
                }
            }
        }
    }
}

// =========================================================
// MARK: - Shared Components
// =========================================================

private struct AuthHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(StudyTheme.surface2)
                    .clipShape(Circle())
            }
            Spacer()
            Text(title)
                .font(StudyFont.subtitle)
                .foregroundStyle(StudyTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface
            .overlay(alignment: .bottom) {
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
            })
    }
}

private struct AuthProviderButton: View {
    let icon:      String
    let label:     String
    let color:     Color
    let isLoading: Bool
    let action:    () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(isLoading ? "Signing in…" : label)
                    .font(StudyFont.subtitle)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: color.opacity(0.4), radius: 10, y: 4)
            )
        }
        .disabled(isLoading)
    }
}

private struct AuthField: View {
    let icon:             String
    let placeholder:      String
    @Binding var text:    String
    let secure:           Bool
    var focused:          FocusState<EmailAuthScreen.Field?>.Binding
    let field:            EmailAuthScreen.Field
    let next:             EmailAuthScreen.Field?
    var trailingIcon:     String?       = nil
    var trailingAction:   (() -> Void)? = nil

    var body: some View {
        HStack(spacing: StudySpacing.small) {
            Image(systemName: icon)
                .foregroundStyle(StudyTheme.accent)
                .frame(width: 20)

            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(StudyFont.body)
            .foregroundStyle(StudyTheme.primaryText)
            .focused(focused, equals: field)
            .submitLabel(next == nil ? .done : .next)
            .onSubmit {
                if let n = next { focused.wrappedValue = n }
                else { focused.wrappedValue = nil }
            }

            if let icon = trailingIcon {
                Button(action: { trailingAction?() }) {
                    Image(systemName: icon)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, StudySpacing.medium)
        .frame(height: 52)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(focused.wrappedValue == field ? StudyTheme.accent : StudyTheme.surfaceStroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)
    }
}

private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 13))
        Text(message)
            .font(StudyFont.tiny)
    }
    .foregroundStyle(StudyTheme.danger)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(StudySpacing.medium)
    .background(StudyTheme.danger.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .transition(.move(edge: .top).combined(with: .opacity))
}
