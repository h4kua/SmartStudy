import SwiftUI

// MARK: - Colours

enum StudyTheme {
    static let background  = Color(red: 0.040, green: 0.040, blue: 0.094)
    static let surface     = Color(red: 0.086, green: 0.086, blue: 0.149)
    static let surface2    = Color(red: 0.120, green: 0.120, blue: 0.196)
    static let surface3    = Color(red: 0.155, green: 0.155, blue: 0.243)

    static let accent     = Color(red: 0.40, green: 0.60, blue: 1.00)
    static let accentSoft = accent.opacity(0.12)

    static let focusColor      = Color(red: 0.40, green: 0.60, blue: 1.00)
    static let shortBreakColor = Color(red: 0.22, green: 0.80, blue: 0.58)
    static let longBreakColor  = Color(red: 0.72, green: 0.46, blue: 1.00)

    static let success = Color(red: 0.22, green: 0.82, blue: 0.48)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.22)
    static let danger  = Color(red: 1.00, green: 0.38, blue: 0.38)

    static let primaryText   = Color.white
    static let secondaryText = Color(red: 0.54, green: 0.54, blue: 0.66)
    static let tertiaryText  = Color(red: 0.33, green: 0.33, blue: 0.44)

    static let surfaceStroke = Color.white.opacity(0.07)
    static let shadow        = Color.black.opacity(0.40)

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.40, green: 0.60, blue: 1.00),
                 Color(red: 0.64, green: 0.38, blue: 1.00)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let focusGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.32, blue: 0.76),
                 Color(red: 0.08, green: 0.14, blue: 0.50)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                )
        )
        .shadow(color: StudyTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Button styles

struct PrimaryStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StudyTheme.accentGradient)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StudyTheme.accent)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(StudyTheme.accent.opacity(0.35), lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: StudyTheme.shadow, radius: 16, x: 0, y: 8)
    }
}
