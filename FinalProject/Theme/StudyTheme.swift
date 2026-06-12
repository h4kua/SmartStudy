import SwiftUI

// MARK: - Colours

enum StudyTheme {
    static let background  = Color(red: 0.05, green: 0.06, blue: 0.12)
    static let surface     = Color(red: 0.10, green: 0.11, blue: 0.20)
    static let surface2    = Color(red: 0.15, green: 0.16, blue: 0.27)
    static let surface3    = Color(red: 0.20, green: 0.21, blue: 0.33)

    static let accent      = Color(red: 0.38, green: 0.58, blue: 1.00)   // #6194FF
    static let accentSoft  = accent.opacity(0.15)

    static let focusColor      = Color(red: 0.38, green: 0.58, blue: 1.00)
    static let shortBreakColor = Color(red: 0.20, green: 0.76, blue: 0.56)
    static let longBreakColor  = Color(red: 0.70, green: 0.44, blue: 1.00)

    static let success   = Color(red: 0.20, green: 0.78, blue: 0.46)
    static let warning   = Color(red: 1.00, green: 0.77, blue: 0.20)
    static let danger    = Color(red: 1.00, green: 0.35, blue: 0.35)

    static let primaryText   = Color.white
    static let secondaryText = Color(red: 0.54, green: 0.55, blue: 0.70)
    static let tertiaryText  = Color(red: 0.33, green: 0.34, blue: 0.46)

    static let surfaceStroke = Color.white.opacity(0.08)
    static let shadow        = Color.black.opacity(0.50)

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.38, green: 0.58, blue: 1.00),
                 Color(red: 0.62, green: 0.38, blue: 1.00)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let focusGradient = LinearGradient(
        colors: [Color(red: 0.28, green: 0.48, blue: 0.95),
                 Color(red: 0.15, green: 0.25, blue: 0.70)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Spacing

enum StudySpacing {
    static let xSmall: CGFloat = 4
    static let small:  CGFloat = 8
    static let medium: CGFloat = 16
    static let large:  CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

// MARK: - Typography

enum StudyFont {
    static let hero      = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let metric    = Font.system(size: 56, weight: .black, design: .rounded)
    static let title     = Font.system(.title2,  design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.title3,  design: .rounded).weight(.semibold)
    static let subtitle  = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let body      = Font.system(.body,    design: .rounded)
    static let caption   = Font.system(.caption, design: .rounded)
    static let tiny      = Font.system(.caption2, design: .rounded).weight(.medium)
}

// MARK: - Reusable card views

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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: StudyTheme.shadow, radius: 12, x: 0, y: 6)
    }
}

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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: StudyTheme.shadow, radius: 16, x: 0, y: 8)
    }
}
