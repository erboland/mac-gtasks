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
        SharedStore.load().lists
            .filter { identifiers.contains($0.id) }
            .map(TaskListEntity.init)
    }

    func suggestedEntities() async throws -> [TaskListEntity] {
        let lists = SharedStore.load().lists
        if lists.isEmpty {
            return SampleData.snapshot().lists.map(TaskListEntity.init)
        }
        return lists.map(TaskListEntity.init)
    }

    func defaultResult() async -> TaskListEntity? {
        let snapshot = SharedStore.load()
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
        let currentlyCompleted = snapshot.list(id: listId)?.tasks.first(where: { $0.id == taskId })?.isCompleted ?? false
        await SyncService.setCompleted(listId: listId, taskId: taskId, completed: !currentlyCompleted)
        return .result()
    }
}
