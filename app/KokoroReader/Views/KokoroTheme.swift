import SwiftUI

enum KokoroTheme {
    // Backgrounds
    static let bgBase = Color(red: 0.04, green: 0.04, blue: 0.08)       // #0a0a14
    static let bgSurface = Color(red: 0.07, green: 0.07, blue: 0.12)    // #12121e
    static let bgElevated = Color(red: 0.10, green: 0.10, blue: 0.16)   // #1a1a2a

    // Accents
    static let accent = Color(red: 0.545, green: 0.545, blue: 0.804)    // #8b8bcd
    static let accentDim = Color(red: 0.486, green: 0.486, blue: 0.788) // #7c7cc9
    static let accentBright = Color(red: 0.655, green: 0.545, blue: 0.98) // #a78bfa

    // Text
    static let textPrimary = Color(red: 0.91, green: 0.91, blue: 0.96)  // #e8e8f4
    static let textSecondary = Color(red: 0.533, green: 0.533, blue: 0.667) // #8888aa
    static let textMuted = Color(red: 0.353, green: 0.353, blue: 0.478) // #5a5a7a

    // Semantic
    static let success = Color(red: 0.29, green: 0.87, blue: 0.50)      // #4ade80
    static let error = Color(red: 0.973, green: 0.443, blue: 0.443)     // #f87171

    // Border
    static let border = Color.white.opacity(0.08)
    static let borderHover = Color.white.opacity(0.15)

    // Progress gradient
    static let progressGradient = LinearGradient(
        colors: [accentDim, accentBright],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Section header style
    struct SectionHeader: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(KokoroTheme.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
        }
    }
}

extension View {
    func kokoroSectionHeader() -> some View {
        modifier(KokoroTheme.SectionHeader())
    }
}
