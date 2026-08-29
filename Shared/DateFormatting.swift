import Foundation

enum TaskDateFormatting {
    static func dueLabel(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let dayDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if dayDiff > 1 && dayDiff < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func isOverdue(_ date: Date, now: Date = Date()) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: now)
    }

    static func isToday(_ date: Date, now: Date = Date()) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: now)
    }
}
