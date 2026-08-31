import AppIntents
import SwiftUI
import WidgetKit

struct TasksEntry: TimelineEntry {
    let date: Date
    let list: TaskList?
    let boards: [TaskList]
    let pageOffset: Int
    let showingCompleted: Bool
    let isDemo: Bool
    let isSignedIn: Bool
    let isPlaceholder: Bool

    var listColor: Color {
        guard let list else { return ListColor.remindersOrange }
        return ListColor.color(for: list.id)
    }
}

struct TasksProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        let snapshot = SharedStore.loadForWidget()
        if snapshot.lists.isEmpty {
            return entry(from: SampleData.snapshot(), intent: ListConfigurationIntent(), date: Date(), placeholder: true)
        }
        return entry(from: snapshot, intent: ListConfigurationIntent(), date: Date(), placeholder: true)
    }

    func snapshot(for configuration: ListConfigurationIntent, in context: Context) async -> TasksEntry {
        if context.isPreview && SharedStore.loadForWidget().lists.isEmpty {
            return entry(from: SampleData.snapshot(), intent: configuration, date: Date(), placeholder: false)
        }
        return await currentEntry(for: configuration)
    }

    func timeline(for configuration: ListConfigurationIntent, in context: Context) async -> Timeline<TasksEntry> {
        let now = Date()
        let first = await currentEntry(for: configuration, at: now)
        var entries = [first]
        if SharedStore.hasFadingCompletions(at: now) {
            entries.append(await currentEntry(for: configuration, at: now.addingTimeInterval(SharedStore.fadeDuration)))
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60)))
    }

    private func currentEntry(for configuration: ListConfigurationIntent, at date: Date = Date()) async -> TasksEntry {
        var snapshot = SharedStore.loadForWidget()
        if snapshot.lists.isEmpty, TokenFileStore.load() != nil {
            if let remote = try? await GoogleTasksClient.fetchAll() {
                SharedStore.save(remote)
                snapshot = remote
            }
        }
        return entry(from: snapshot, intent: configuration, date: date, placeholder: false)
    }

    private func entry(from snapshot: TasksSnapshot, intent: ListConfigurationIntent, date: Date, placeholder: Bool) -> TasksEntry {
        let signedIn = (!snapshot.isDemo && !snapshot.lists.isEmpty)
            || snapshot.accountEmail != nil
            || TokenFileStore.load() != nil

        var list: TaskList?
        if SharedStore.isShowingPicker() {
            list = nil
        } else if let id = SharedStore.focusedListId(), let match = snapshot.list(id: id) {
            list = match
        } else if let id = intent.list?.id, let match = snapshot.list(id: id) {
            list = match
        }

        if var visible = list {
            let showingCompleted = SharedStore.isShowingCompleted()
            if showingCompleted {
                visible.tasks = visible.completedTasks.sorted {
                    ($0.completed ?? .distantPast) > ($1.completed ?? .distantPast)
                }
            } else {
                var merged = visible.incompleteTasks
                let fading = SharedStore.fadingCompletions(visibleAt: date, listId: visible.id)
                for item in fading where !merged.contains(where: { $0.id == item.id }) {
                    merged.append(item)
                }
                merged.sort { $0.position < $1.position }
                visible.tasks = merged
            }
            visible.openTaskCount = visible.incompleteTasks.count
            list = visible
        }

        let total = list?.tasks.count ?? 0
        var pageOffset = list.map { SharedStore.taskPageOffset(for: $0.id) } ?? 0
        if total == 0 || pageOffset >= total {
            pageOffset = 0
        }

        let focusedId = list?.id
        let boards = snapshot.lists.map { board -> TaskList in
            var copy = board
            copy.openTaskCount = board.incompleteTasks.count
            if board.id == focusedId {
                copy.tasks = board.incompleteTasks
            } else {
                copy.tasks = []
            }
            return copy
        }

        return TasksEntry(
            date: date,
            list: list,
            boards: boards,
            pageOffset: pageOffset,
            showingCompleted: SharedStore.isShowingCompleted(),
            isDemo: snapshot.isDemo,
            isSignedIn: signedIn,
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
                    now: entry.date,
                    showsListSwitcher: !entry.boards.isEmpty,
                    pageOffset: entry.pageOffset,
                    showingCompleted: entry.showingCompleted
                )
            } else if !entry.boards.isEmpty || entry.isSignedIn {
                WidgetBoardPicker(boards: entry.boards, family: family)
            } else {
                emptySignIn
            }
        }
        .containerBackground(.background, for: .widget)
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

struct WidgetBoardPicker: View {
    var boards: [TaskList]
    var family: WidgetFamily

    private var metrics: WidgetMetrics { WidgetMetrics.forFamily(family) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My Lists")
                .font(.system(size: metrics.titleFont, weight: .semibold))
                .foregroundStyle(ListColor.remindersOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .widgetAccentable()
                .padding(.bottom, metrics.headerSpacing)

            if boards.isEmpty {
                Text("Open Tasks to refresh your lists")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ViewThatFits(in: .vertical) {
                    boardStack(count: min(boards.count, metrics.rowCount))
                    boardStack(count: min(boards.count, max(1, metrics.rowCount - 1)))
                    boardStack(count: min(boards.count, max(1, metrics.rowCount - 2)))
                    boardStack(count: min(boards.count, max(1, metrics.rowCount - 3)))
                    boardStack(count: min(boards.count, 1))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, metrics.horizontalPad)
        .padding(.top, metrics.topPad)
        .padding(.bottom, metrics.bottomPad)
        .clipped()
    }

    private func boardStack(count: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(boards.prefix(count).enumerated()), id: \.element.id) { index, board in
                if index > 0 {
                    Divider()
                        .opacity(0.45)
                }
                Button(intent: SelectListIntent(listId: board.id)) {
                    HStack(spacing: 8) {
                        ListGlyph(color: ListColor.color(for: board.id), size: metrics.glyphSize)
                        Text(board.title)
                            .font(.system(size: metrics.rowFont))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if metrics.showsCount {
                            Text("\(board.displayedOpenCount)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, metrics.rowVerticalPad)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .invalidatableContent()
            }
        }
    }
}

struct WidgetMetrics {
    var rowCount: Int
    var checkboxSize: CGFloat
    var glyphSize: CGFloat
    var titleFont: CGFloat
    var rowFont: CGFloat
    var showsGlyph: Bool
    var showsChevron: Bool
    var showsSubtitle: Bool
    var showsCount: Bool
    var horizontalPad: CGFloat
    var topPad: CGFloat
    var bottomPad: CGFloat
    var headerSpacing: CGFloat
    var rowVerticalPad: CGFloat

    static func forFamily(_ family: WidgetFamily) -> WidgetMetrics {
        switch family {
        case .systemSmall:
            return WidgetMetrics(
                rowCount: 4,
                checkboxSize: 15,
                glyphSize: 20,
                titleFont: 14,
                rowFont: 13,
                showsGlyph: false,
                showsChevron: true,
                showsSubtitle: false,
                showsCount: false,
                horizontalPad: 12,
                topPad: 12,
                bottomPad: 10,
                headerSpacing: 6,
                rowVerticalPad: 5
            )
        case .systemMedium:
            return WidgetMetrics(
                rowCount: 5,
                checkboxSize: 18,
                glyphSize: 22,
                titleFont: 16,
                rowFont: 14,
                showsGlyph: true,
                showsChevron: true,
                showsSubtitle: false,
                showsCount: true,
                horizontalPad: 14,
                topPad: 12,
                bottomPad: 10,
                headerSpacing: 6,
                rowVerticalPad: 4
            )
        case .systemLarge:
            return WidgetMetrics(
                rowCount: 8,
                checkboxSize: 20,
                glyphSize: 24,
                titleFont: 17,
                rowFont: 15,
                showsGlyph: true,
                showsChevron: true,
                showsSubtitle: true,
                showsCount: true,
                horizontalPad: 16,
                topPad: 14,
                bottomPad: 12,
                headerSpacing: 8,
                rowVerticalPad: 5
            )
        case .systemExtraLarge:
            return WidgetMetrics(
                rowCount: 10,
                checkboxSize: 20,
                glyphSize: 24,
                titleFont: 17,
                rowFont: 15,
                showsGlyph: true,
                showsChevron: true,
                showsSubtitle: true,
                showsCount: true,
                horizontalPad: 16,
                topPad: 14,
                bottomPad: 12,
                headerSpacing: 8,
                rowVerticalPad: 5
            )
        default:
            return forFamily(.systemMedium)
        }
    }
}

struct RemindersListWidgetLayout: View {
    var list: TaskList
    var color: Color
    var family: WidgetFamily
    var now: Date
    var showsListSwitcher = false
    var pageOffset = 0
    var showingCompleted = false

    private var metrics: WidgetMetrics { WidgetMetrics.forFamily(family) }

    private var allTasks: [TaskItem] { list.tasks }

    private var pageSize: Int {
        max(1, metrics.rowCount - 1)
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(allTasks.count) / Double(pageSize))))
    }

    private var currentPage: Int {
        min(pageCount, pageOffset / pageSize + 1)
    }

    private var showsPager: Bool {
        allTasks.count > pageSize || pageOffset > 0
    }

    private var tasks: [TaskItem] {
        Array(allTasks.dropFirst(pageOffset).prefix(pageSize))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, metrics.headerSpacing)

            if allTasks.isEmpty {
                allDone
                pager
                    .padding(.top, 6)
            } else {
                ViewThatFits(in: .vertical) {
                    taskStack(count: tasks.count)
                    taskStack(count: max(1, tasks.count - 1))
                    taskStack(count: max(1, tasks.count - 2))
                    taskStack(count: max(1, tasks.count - 3))
                    taskStack(count: max(1, tasks.count - 4))
                    taskStack(count: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                pager
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, metrics.horizontalPad)
        .padding(.top, metrics.topPad)
        .padding(.bottom, metrics.bottomPad)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(intent: ShowListsIntent(currentListId: list.id)) {
                HStack(spacing: 6) {
                    if metrics.showsGlyph {
                        ListGlyph(color: color, size: metrics.glyphSize)
                    }
                    Text(showingCompleted ? "Completed" : list.title)
                        .font(.system(size: metrics.titleFont, weight: .semibold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showsListSwitcher, metrics.showsChevron, !showingCompleted {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color.opacity(0.8))
                    }
                }
                .widgetAccentable()
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!showsListSwitcher)
            .frame(maxWidth: .infinity, alignment: .leading)
            .invalidatableContent()

            Link(destination: AppGroup.newTaskURL(listId: list.id)) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .widgetAccentable()
        }
    }

    private var pager: some View {
        HStack(spacing: 8) {
            if showsPager {
                HStack(spacing: 6) {
                    Button(intent: pageIntent(step: -1)) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .invalidatableContent()

                    Text("\(currentPage)/\(pageCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()

                    Button(intent: pageIntent(step: 1)) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .invalidatableContent()
                }
            } else {
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Button(intent: ShowCompletedIntent(listId: list.id)) {
                Text(showingCompleted ? "Open" : "Completed")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .invalidatableContent()
        }
        .foregroundStyle(color.opacity(0.9))
        .frame(maxWidth: .infinity)
        .widgetAccentable()
    }

    private func pageIntent(step: Int) -> TurnTaskPageIntent {
        TurnTaskPageIntent(
            listId: list.id,
            pageSize: pageSize,
            totalCount: allTasks.count,
            step: step
        )
    }

    private func taskStack(count: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.prefix(count).enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider()
                        .opacity(0.45)
                }
                WidgetTaskRow(
                    task: task,
                    color: color,
                    checkboxSize: metrics.checkboxSize,
                    fontSize: metrics.rowFont,
                    verticalPad: metrics.rowVerticalPad,
                    showSubtitle: metrics.showsSubtitle,
                    now: now
                )
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
            Text(showingCompleted ? "No Completed Tasks" : "All Done")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetTaskRow: View {
    var task: TaskItem
    var color: Color
    var checkboxSize: CGFloat
    var fontSize: CGFloat
    var verticalPad: CGFloat
    var showSubtitle: Bool
    var now: Date

    var body: some View {
        Toggle(isOn: task.isCompleted, intent: ToggleTaskIntent(taskId: task.id, listId: task.listId)) {
            Text(task.trimmedTitle)
        }
        .toggleStyle(
            ChecklistToggleStyle(
                color: color,
                checkboxSize: checkboxSize,
                fontSize: fontSize,
                showSubtitle: showSubtitle,
                subtitle: subtitleText,
                now: now
            )
        )
        .padding(.vertical, verticalPad)
        .invalidatableContent()
    }

    private var subtitleText: String? {
        if let due = task.due {
            return TaskDateFormatting.dueLabel(for: due, now: now)
        }
        if let notes = task.notes, !notes.isEmpty {
            return notes
        }
        return nil
    }
}

struct TasksWidget: Widget {
    let kind = AppGroup.widgetKind

    var body: some WidgetConfiguration {
        TasksWidgetConfiguration.make(kind: kind)
    }
}

struct TasksBoardsWidget: Widget {
    let kind = AppGroup.widgetKindLegacy

    var body: some WidgetConfiguration {
        TasksWidgetConfiguration.make(kind: kind)
    }
}

enum TasksWidgetConfiguration {
    static func make(kind: String) -> some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ListConfigurationIntent.self, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("List")
        .description("Keep track of a Google Tasks list. Check items off right from the widget.")
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#Preview("Medium", as: .systemMedium) {
    TasksWidget()
} timeline: {
    TasksEntry(date: .now, list: SampleData.snapshot().lists[0], boards: SampleData.snapshot().lists, pageOffset: 0, showingCompleted: false, isDemo: true, isSignedIn: false, isPlaceholder: false)
}
