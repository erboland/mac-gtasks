import Foundation

struct TasksSnapshot: Codable, Equatable, Sendable {
    var accountEmail: String?
    var isDemo: Bool
    var lists: [TaskList]
    var selectedListId: String?
    var lastSyncedAt: Date?

    static let empty = TasksSnapshot(accountEmail: nil, isDemo: true, lists: [], selectedListId: nil, lastSyncedAt: nil)

    var selectedList: TaskList? {
        if let selectedListId, let match = lists.first(where: { $0.id == selectedListId }) {
            return match
        }
        return lists.first
    }

    func list(id: String) -> TaskList? {
        lists.first(where: { $0.id == id })
    }

    /// Keep open tasks plus recent completed so the widget can show Done and animate checks.
    func compactedForWidget(maxCompletedPerList: Int = 40) -> TasksSnapshot {
        var copy = self
        copy.lists = lists.map { list in
            var trimmed = list
            let open = list.incompleteTasks
            let done = Array(list.completedTasks.sorted { ($0.completed ?? .distantPast) > ($1.completed ?? .distantPast) }.prefix(maxCompletedPerList))
            trimmed.tasks = open + done
            trimmed.openTaskCount = open.count
            return trimmed
        }
        return copy
    }
}

struct TaskList: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var updated: Date?
    var tasks: [TaskItem]
    var openTaskCount: Int? = nil

    var incompleteTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted && $0.parent == nil }
    }

    var displayedOpenCount: Int {
        openTaskCount ?? incompleteTasks.count
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted && $0.parent == nil }
    }

    func subtasks(of parentId: String) -> [TaskItem] {
        tasks
            .filter { $0.parent == parentId }
            .sorted { $0.position < $1.position }
    }
}

struct TaskItem: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: String
    var listId: String
    var title: String
    var notes: String?
    var status: String
    var due: Date?
    var completed: Date?
    var updated: Date?
    var parent: String?
    var position: String
    var webViewLink: String?

    var isCompleted: Bool { status == "completed" }

    var trimmedTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "New Task" : value
    }
}

struct FadingCompletion: Codable, Equatable, Sendable {
    var task: TaskItem
    var completedAt: Date
}

struct OAuthTokens: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiry: Date
    var tokenType: String
    var email: String?

    var isExpired: Bool {
        expiry.addingTimeInterval(-60) < Date()
    }
}
