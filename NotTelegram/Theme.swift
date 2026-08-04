import SwiftUI

// Тёмный стеклянный язык (см. DESIGN.md). Глубина — через материалы,
// а не декоративные градиенты; цвет держим сдержанным.
enum Theme {
    static let bg = Color(red: 0.025, green: 0.026, blue: 0.04)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStrong = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.08)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textMuted = Color.white.opacity(0.40)

    static let accent = Color(red: 0.44, green: 0.56, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.32, blue: 0.42)
    static let online = Color(red: 0.30, green: 0.85, blue: 0.45)

    // Мягкие заливки-заглушки вместо картинок (пока нет ассетов).
    static let fills: [[Color]] = [
        [Color(red: 0.36, green: 0.31, blue: 0.78), Color(red: 0.24, green: 0.55, blue: 0.86)],
        [Color(red: 0.85, green: 0.36, blue: 0.28), Color(red: 0.55, green: 0.20, blue: 0.30)],
        [Color(red: 0.20, green: 0.62, blue: 0.55), Color(red: 0.12, green: 0.40, blue: 0.45)],
        [Color(red: 0.83, green: 0.33, blue: 0.55), Color(red: 0.45, green: 0.20, blue: 0.50)]
    ]
}
