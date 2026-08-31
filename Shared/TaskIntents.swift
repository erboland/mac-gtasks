import AppIntents
import Foundation
import WidgetKit

struct TaskListEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "List"
    static var defaultQuery = TaskListQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    init(_ list: TaskList) {
        self.id = list.id
        self.title = list.title
    }
}

struct TaskListQuery: EntityQuery {
    func entities(for identifiers: [TaskListEntity.ID]) async throws -> [TaskListEntity] {
        SharedStore.loadForWidget().lists
            .filter { identifiers.contains($0.id) }
            .map(TaskListEntity.init)
    }

    func suggestedEntities() async throws -> [TaskListEntity] {
        let lists = SharedStore.loadForWidget().lists
        if lists.isEmpty {
            return SampleData.snapshot().lists.map(TaskListEntity.init)
        }
        return lists.map(TaskListEntity.init)
    }

    func defaultResult() async -> TaskListEntity? {
        let snapshot = SharedStore.loadForWidget()
        if let selected = snapshot.selectedList {
            return TaskListEntity(selected)
        }
        return try? await suggestedEntities().first
    }
}

struct ListConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select List"
    static var description: IntentDescription = IntentDescription("Choose which Google Tasks list to show.")

    @Parameter(title: "List")
    var list: TaskListEntity?

    init() {}

    init(list: TaskListEntity?) {
        self.list = list
    }
}

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Marks a Google task complete or incomplete.")
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "Task")
    var taskId: String

    @Parameter(title: "List")
    var listId: String

    init() {}

    init(taskId: String, listId: String) {
        self.taskId = taskId
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        let snapshot = SharedStore.load()
        let task = snapshot.list(id: listId)?.tasks.first(where: { $0.id == taskId })
        let currentlyCompleted = task?.isCompleted ?? false
        if currentlyCompleted {
            SharedStore.clearFadingCompletion(id: taskId)
        } else if let task {
            SharedStore.markFadingCompletion(task)
        }
        await SyncService.setCompleted(listId: listId, taskId: taskId, completed: !currentlyCompleted)
        return .result()
    }
}

struct ShowCompletedIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Completed Tasks"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "List")
    var listId: String

    init() {}

    init(listId: String) {
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        let next = !SharedStore.isShowingCompleted()
        SharedStore.setShowingCompleted(next)
        SharedStore.setTaskPageOffset(0, for: listId)
        return .result()
    }
}

struct NewTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "New Task"
    static var isDiscoverable = false
    static var openAppWhenRun = true

    @Parameter(title: "List")
    var listId: String

    init() {}

    init(listId: String) {
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        SharedStore.setPendingCompose(listId: listId)
        DistributedNotificationCenter.default().postNotificationName(
            AppGroup.composeNotification,
            object: listId,
            userInfo: nil,
            deliverImmediately: true
        )
        return .result()
    }
}

struct SelectListIntent: AppIntent {
    static var title: LocalizedStringResource = "Show List"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "List")
    var listId: String

    init() {}

    init(listId: String) {
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        SharedStore.setShowingPicker(false)
        SharedStore.setTaskPageOffset(0, for: listId)
        SharedStore.setFocusedListId(listId)
        let snapshot = SharedStore.load()
        if snapshot.list(id: listId) != nil {
            SharedStore.mutate { $0.selectedListId = listId }
        }
        return .result()
    }
}

struct TurnTaskPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Show More Tasks"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: "List")
    var listId: String

    @Parameter(title: "Page Size")
    var pageSize: Int

    @Parameter(title: "Total")
    var totalCount: Int

    @Parameter(title: "Step")
    var step: Int

    init() {}

    init(listId: String, pageSize: Int, totalCount: Int, step: Int) {
        self.listId = listId
        self.pageSize = pageSize
        self.totalCount = totalCount
        self.step = step
    }

    func perform() async throws -> some IntentResult {
        SharedStore.advanceTaskPage(listId: listId, pageSize: pageSize, totalCount: totalCount, step: step)
        return .result()
    }
}

struct ShowListsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show All Lists"
    static var isDiscoverable = false
    static var openAppWhenRun = false

    /// WidgetKit on macOS is more reliable when interactive intents have a parameter.
    @Parameter(title: "Current List")
    var currentListId: String

    init() {}

    init(currentListId: String) {
        self.currentListId = currentListId
    }

    func perform() async throws -> some IntentResult {
        SharedStore.setShowingPicker(true)
        return .result()
    }
}
