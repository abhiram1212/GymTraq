import SwiftUI

// MARK: - GymTraq design system
// Apple Fitness-inspired: true black canvas, flat #1C1C1E cards, one energetic
// lime accent (Exercise-ring green), SF Rounded display type, capsule CTAs.

extension Color {
    /// Primary accent — Fitness "Exercise ring" lime. CTAs, selection, highlights.
    static let appAccent = Color(red: 0.66, green: 0.96, blue: 0.20)
    /// Deeper companion green for gradient stops.
    static let appAccentDeep = Color(red: 0.30, green: 0.80, blue: 0.25)
    /// Destructive / errors — Fitness "Move ring" red-pink.
    static let appDanger = Color(red: 0.98, green: 0.20, blue: 0.35)
    /// Success confirmations.
    static let appSuccess = Color(red: 0.36, green: 0.90, blue: 0.45)
    /// Card surface — matches systemGray6 dark (#1C1C1E).
    static let appCard = Color(red: 0.11, green: 0.11, blue: 0.12)
    /// Elevated surface for fields/rows on top of cards (#2C2C2E).
    static let appCardElevated = Color(red: 0.17, green: 0.17, blue: 0.18)
}

/// Apple-style press feedback: cards shrink slightly under the finger.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
