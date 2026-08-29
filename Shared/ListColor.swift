import SwiftUI

enum ListColor {
    /// Palette sampled from the macOS Reminders list colors.
    static let palette: [Color] = [
        Color(red: 0.98, green: 0.42, blue: 0.18), // orange — Reminders default
        Color(red: 0.20, green: 0.48, blue: 0.96), // blue
        Color(red: 0.30, green: 0.72, blue: 0.40), // green
        Color(red: 0.69, green: 0.32, blue: 0.87), // purple
        Color(red: 0.94, green: 0.27, blue: 0.33), // red
        Color(red: 0.98, green: 0.72, blue: 0.11), // yellow
        Color(red: 0.35, green: 0.68, blue: 0.76), // teal
        Color(red: 0.55, green: 0.47, blue: 0.38), // brown
        Color(red: 0.37, green: 0.36, blue: 0.84), // indigo
        Color(red: 1.00, green: 0.27, blue: 0.58)  // pink
    ]

    static func color(for listId: String) -> Color {
        let hash = listId.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    /// Default Reminders orange, used for the primary "My Tasks" list when possible.
    static let remindersOrange = palette[0]
}
