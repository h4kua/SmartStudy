import SwiftUI

// =====================================================================
// MARK: - "Aurora" Design System
// A modern, clean dark theme built on a deep ink-blue space with an
// indigo → violet → fuchsia accent and mint / violet secondary tones.
// Every screen reads from these tokens, so the whole app stays cohesive.
// =====================================================================

// MARK: - Colours

enum StudyTheme {
    // Backgrounds — layered "elevation" surfaces on a deep ink base.
    static let background  = Color(red: 0.039, green: 0.043, blue: 0.078)   // #0A0B14
    static let surface     = Color(red: 0.075, green: 0.082, blue: 0.125)   // #131520
    static let surface2    = Color(red: 0.110, green: 0.118, blue: 0.176)   // #1C1E2D
    static let surface3    = Color(red: 0.153, green: 0.165, blue: 0.243)   // #272A3E

    // Primary accent — periwinkle indigo. Bright enough to read as text.
    static let accent     = Color(red: 0.486, green: 0.553, blue: 1.000)    // #7C8DFF
    static let accentSoft = accent.opacity(0.14)

    // Semantic / category tones.
    static let focusColor      = accent
    static let shortBreakColor = Color(red: 0.176, green: 0.831, blue: 0.749) // mint  #2DD4BF
    static let longBreakColor  = Color(red: 0.710, green: 0.482, blue: 1.000) // violet #B57BFF

    static let success = Color(red: 0.204, green: 0.827, blue: 0.600)  // emerald #34D399
    static let warning = Color(red: 0.984, green: 0.749, blue: 0.141)  // amber   #FBBF24
    static let danger  = Color(red: 0.984, green: 0.443, blue: 0.522)  // rose    #FB7185

    // Text — off-white primary for a softer, premium feel.
    static let primaryText   = Color(red: 0.961, green: 0.965, blue: 1.000)
    static let secondaryText = Color(red: 0.580, green: 0.604, blue: 0.722)
    static let tertiaryText  = Color(red: 0.360, green: 0.380, blue: 0.498)

    static let surfaceStroke = Color.white.opacity(0.08)
    static let shadow        = Color.black.opacity(0.45)
    static let accentGlow    = accent.opacity(0.45)

    // Gradients.
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.388, green: 0.400, blue: 0.945),   // indigo  #6366F1
                 Color(red: 0.545, green: 0.361, blue: 0.965),   // violet  #8B5CF6
                 Color(red: 0.851, green: 0.275, blue: 0.937)],  // fuchsia #D946EF
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Deep aurora used for hero banners.
    static let focusGradient = LinearGradient(
        colors: [Color(red: 0.141, green: 0.106, blue: 0.369),   // #241B5E
                 Color(red: 0.282, green: 0.169, blue: 0.659),   // #4828A8
                 Color(red: 0.486, green: 0.227, blue: 0.929)],  // #7C3AED
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Mint → indigo accent for special highlights.
    static let auroraGradient = LinearGradient(
        colors: [Color(red: 0.176, green: 0.831, blue: 0.749),
                 Color(red: 0.486, green: 0.553, blue: 1.000)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Subtle vertical wash applied behind whole screens for depth.
    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.063, green: 0.063, blue: 0.118),
                 Color(red: 0.039, green: 0.043, blue: 0.078)],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: System chrome appearance (tab + nav bars)

    static func configureAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundColor = UIColor(red: 0.063, green: 0.067, blue: 0.110, alpha: 0.92)
        tab.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.06)

        let normal = UIColor(red: 0.46, green: 0.48, blue: 0.58, alpha: 1)
        let selected = UIColor(StudyTheme.accent)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = normal
            item.normal.titleTextAttributes = [.foregroundColor: normal]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - Spacing

enum StudySpacing {
    static let xSmall:  CGFloat = 4
    static let small:   CGFloat = 8
    static let medium:  CGFloat = 16
    static let large:   CGFloat = 24
    static let xLarge:  CGFloat = 32
    static let xxLarge: CGFloat = 52
}

// MARK: - Corner radii

enum StudyRadius {
    static let small:  CGFloat = 12
    static let medium: CGFloat = 16
    static let large:  CGFloat = 20
    static let xLarge: CGFloat = 26
}

// MARK: - Typography

enum StudyFont {
    static let hero      = Font.system(.largeTitle, design: .rounded).weight(.black)
    static let metric    = Font.system(size: 52, weight: .black, design: .rounded)
    static let title     = Font.system(.title2,      design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3,      design: .rounded).weight(.semibold)
    static let subtitle  = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let body      = Font.system(.body, design: .rounded)
    static let caption   = Font.system(.caption, design: .rounded)
    static let tiny      = Font.system(.caption2, design: .rounded).weight(.medium)
}

// MARK: - Card

struct StudyCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudySpacing.medium) {
            if let title {
                Text(title)
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
            }
            content
        }
        .padding(StudySpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StudyRadius.large, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    // Soft top highlight → bottom shade for a "lit from above" look.
                    RoundedRectangle(cornerRadius: StudyRadius.large, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: StudyTheme.shadow, radius: 14, x: 0, y: 8)
    }
}

// MARK: - Button styles

struct PrimaryStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: StudyRadius.medium, style: .continuous)
                    .fill(StudyTheme.accentGradient)
            )
            .shadow(color: StudyTheme.accentGlow.opacity(configuration.isPressed ? 0.2 : 0.5),
                    radius: configuration.isPressed ? 6 : 14, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct GhostStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StudyTheme.accent)
            .background(
                RoundedRectangle(cornerRadius: StudyRadius.medium, style: .continuous)
                    .fill(StudyTheme.accentSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: StudyRadius.medium, style: .continuous)
                            .stroke(StudyTheme.accent.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Gradient card (hero banners)

struct GradientStudyCard<Content: View>: View {
    let gradient: LinearGradient
    let content: Content

    init(gradient: LinearGradient = StudyTheme.accentGradient,
         @ViewBuilder content: () -> Content) {
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        content
            .padding(StudySpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: StudyRadius.xLarge, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: StudyTheme.shadow, radius: 18, x: 0, y: 10)
    }
}

// MARK: - Reusable bits

/// A small pill badge — e.g. streaks, tags, status chips.
struct StudyBadge: View {
    let text: String
    var icon: String? = nil
    var tint: Color = StudyTheme.accent

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(StudyFont.tiny)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tint.opacity(0.15), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

/// A rounded "icon chip" used throughout list rows and tiles.
struct IconChip: View {
    let systemName: String
    var tint: Color = StudyTheme.accent
    var size: CGFloat = 40
    var corner: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(tint.opacity(0.15))
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}
