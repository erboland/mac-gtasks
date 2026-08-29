import SwiftUI
import WidgetKit

struct RemindersCheckbox: View {
    var isCompleted: Bool
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            if isCompleted {
                Circle()
                    .fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(color, lineWidth: max(1.6, size * 0.08))
            }
        }
        .frame(width: size, height: size)
        .widgetAccentable()
    }
}

struct TaskDueText: View {
    var date: Date
    var now: Date = Date()

    var body: some View {
        let overdue = TaskDateFormatting.isOverdue(date, now: now)
        let today = TaskDateFormatting.isToday(date, now: now)
        Text(TaskDateFormatting.dueLabel(for: date, now: now))
            .foregroundStyle(overdue ? Color.red : (today ? Color.orange : Color.secondary))
    }
}

struct ListGlyph: View {
    var color: Color
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "list.bullet")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
            .widgetAccentable()
    }
}
