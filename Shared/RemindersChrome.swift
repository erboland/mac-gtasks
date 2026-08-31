import SwiftUI
import WidgetKit

struct RemindersCheckbox: View {
    var isCompleted: Bool
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color, lineWidth: max(1.6, size * 0.08))
                .opacity(isCompleted ? 0 : 1)
            Circle()
                .fill(color)
                .scaleEffect(isCompleted ? 1 : 0.55)
                .opacity(isCompleted ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .opacity(isCompleted ? 1 : 0)
                .scaleEffect(isCompleted ? 1 : 0.4)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.28), value: isCompleted)
        .widgetAccentable()
    }
}

struct AnimatedStrikeTitle: View {
    var title: String
    var isCompleted: Bool
    var fontSize: CGFloat
    var strikeColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: fontSize))
            .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
            .strikethrough(isCompleted, color: strikeColor.opacity(0.8))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(strikeColor.opacity(0.85))
                        .frame(width: isCompleted ? geo.size.width : 0, height: 1.4)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.32), value: isCompleted)
    }
}

/// Apple’s Reminders widget uses Toggle, which flips `isOn` immediately (optimistic).
struct ChecklistToggleStyle: ToggleStyle {
    var color: Color
    var checkboxSize: CGFloat
    var fontSize: CGFloat
    var showSubtitle: Bool
    var subtitle: String?
    var now: Date = Date()

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            RemindersCheckbox(isCompleted: configuration.isOn, color: color, size: checkboxSize)
            VStack(alignment: .leading, spacing: 1) {
                configuration.label
                    .font(.system(size: fontSize))
                    .foregroundStyle(configuration.isOn ? Color.secondary : Color.primary)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(color.opacity(0.85))
                                .frame(width: configuration.isOn ? geo.size.width : 0, height: 1.35)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .allowsHitTesting(false)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if showSubtitle, !configuration.isOn, let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.32), value: configuration.isOn)
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
