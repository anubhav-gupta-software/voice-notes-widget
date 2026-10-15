import SwiftUI
import UIKit

enum Theme {
    static let paper = adaptive(light: 0xF4EFE6, dark: 0x161311)
    static let card = adaptive(light: 0xFFFCF8, dark: 0x241F1B)
    static let ink = adaptive(light: 0x1F1A17, dark: 0xF4EFE6)
    static let secondary = adaptive(light: 0x6E6560, dark: 0xB7AEA6)
    static let line = adaptive(light: 0xE4DCD1, dark: 0x3A332E)
    static let coral = Color(hex: 0xE24B3B)
    static let amber = Color(hex: 0xE08A3C)
    static let moss = Color(hex: 0x2F7D5A)
    static let widgetInk = Color(hex: 0x1C1815)
    static let widgetCream = Color(hex: 0xF6F1E8)
    static let widgetMuted = Color(hex: 0xB7AEA6)
    static let widgetWave = Color(hex: 0xE7A15A)

    static let recordingLimit: TimeInterval = 30

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum AvatarPalette {
    private static let colors: [UInt32] = [
        0xC46B4A, 0x3E6B5A, 0x3D5A80, 0x8A5A44, 0xA33B3B, 0x6B5B3A
    ]

    static func color(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Color(hex: colors[sum % colors.count])
    }
}

enum NoteFormat {
    static func duration(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func initials(_ name: String) -> String {
        let parts = name.split { $0.isWhitespace }
        let letters = parts.prefix(2).compactMap { $0.first }
        let text = String(letters).uppercased()
        return text.isEmpty ? "?" : text
    }
}
