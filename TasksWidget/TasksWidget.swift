import AppIntents
import SwiftUI
import WidgetKit

struct TasksEntry: TimelineEntry {
    let date: Date
    let list: TaskList?
    let isDemo: Bool
    let isSignedIn: Bool
    let isPlaceholder: Bool

    var listColor: Color {
        guard let list else { return ListColor.remindersOrange }
        return ListColor.color(for: list.id)
    }

    var visibleTasks: [TaskItem] {
        (list?.incompleteTasks ?? []).sorted { $0.position < $1.position }
    }
}

struct TasksProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        entry(from: SampleData.snapshot(), intent: ListConfigurationIntent(), date: Date(), placeholder: true)
    }

    func snapshot(for configuration: ListConfigurationIntent, in context: Context) async -> TasksEntry {
        if context.isPreview && SharedStore.load().lists.isEmpty {
            return entry(from: SampleData.snapshot(), intent: configuration, date: Date(), placeholder: false)
        }
        return currentEntry(for: configuration)
    }

    func timeline(for configuration: ListConfigurationIntent, in context: Context) async -> Timeline<TasksEntry> {
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [currentEntry(for: configuration)], policy: .after(next))
    }

    private func currentEntry(for configuration: ListConfigurationIntent) -> TasksEntry {
        let snapshot = SharedStore.load()
        if snapshot.lists.isEmpty {
            return entry(from: SampleData.snapshot(), intent: configuration, date: Date(), placeholder: false)
        }
        return entry(from: snapshot, intent: configuration, date: Date(), placeholder: false)
    }

    private func entry(from snapshot: TasksSnapshot, intent: ListConfigurationIntent, date: Date, placeholder: Bool) -> TasksEntry {
        let list: TaskList?
        if let id = intent.list?.id {
            list = snapshot.list(id: id) ?? snapshot.selectedList
        } else {
            list = snapshot.selectedList
        }
        return TasksEntry(
            date: date,
            list: list,
            isDemo: snapshot.isDemo,
            isSignedIn: (!snapshot.isDemo && snapshot.accountEmail != nil) || TokenFileStore.load() != nil,
            isPlaceholder: placeholder
        )
    }
}

struct TasksWidgetEntryView: View {
    var entry: TasksEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let list = entry.list {
                RemindersListWidgetLayout(
                    list: list,
                    color: entry.listColor,
                    family: family,
                    now: entry.date
                )
            } else {
                emptySignIn
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "\(AppGroup.urlScheme)://list/\(entry.list?.id ?? "")"))
    }

    private var emptySignIn: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ListColor.remindersOrange)
            Text("Open Tasks to sign in")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RemindersListWidgetLayout: View {
    var list: TaskList
    var color: Color
    var family: WidgetFamily
    var now: Date

    private var rowCount: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 5
        case .systemLarge: return 11
        case .systemExtraLarge: return 16
        default: return 5
        }
    }

    private var checkboxSize: CGFloat {
        family == .systemSmall ? 18 : 22
    }

    private var tasks: [TaskItem] {
        Array(list.incompleteTasks.prefix(rowCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, family == .systemSmall ? 6 : 8)

            if tasks.isEmpty {
                allDone
            } else {
                ViewThatFits(in: .vertical) {
                    taskStack(count: tasks.count)
                    taskStack(count: min(tasks.count, max(1, rowCount - 1)))
                    taskStack(count: min(tasks.count, max(1, rowCount - 2)))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, family == .systemSmall ? 14 : 16)
        .padding(.top, family == .systemSmall ? 12 : 14)
        .padding(.bottom, 10)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if family != .systemSmall {
                ListGlyph(color: color, size: 26)
            }
            Text(list.title)
                .font(.system(size: family == .systemSmall ? 15 : 17, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .widgetAccentable()
            Spacer(minLength: 0)
        }
    }

    private func taskStack(count: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.prefix(count).enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider()
                        .opacity(0.45)
                }
                WidgetTaskRow(task: task, color: color, checkboxSize: checkboxSize, compact: family == .systemSmall, now: now)
            }
        }
    }

    private var allDone: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: family == .systemSmall ? 28 : 36, weight: .semibold))
                .foregroundStyle(color)
                .widgetAccentable()
            Text("All Done")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WidgetTaskRow: View {
    var task: TaskItem
    var color: Color
    var checkboxSize: CGFloat
    var compact: Bool
    var now: Date

    var body: some View {
        Button(intent: ToggleTaskIntent(taskId: task.id, listId: task.listId)) {
            HStack(alignment: .center, spacing: 10) {
                RemindersCheckbox(isCompleted: task.isCompleted, color: color, size: checkboxSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.trimmedTitle)
                        .font(.system(size: compact ? 13 : 15))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !compact {
                        subtitle
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, compact ? 5 : 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .invalidatableContent()
    }

    @ViewBuilder
    private var subtitle: some View {
        if let due = task.due {
            TaskDueText(date: due, now: now)
        } else if let notes = task.notes, !notes.isEmpty {
            Text(notes)
                .foregroundStyle(.secondary)
        }
    }
}

struct TasksWidget: Widget {
    let kind = AppGroup.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ListConfigurationIntent.self, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("List")
        .description("Keep track of a Google Tasks list. Check items off right from the widget.")
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
    }
}

#Preview("Medium", as: .systemMedium) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, list: SampleData.snapshot().lists[0], isDemo: true, isSignedIn: false, isPlaceholder: false)
}
