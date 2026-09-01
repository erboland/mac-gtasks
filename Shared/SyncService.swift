import Foundation
import WidgetKit

enum SyncService {
    static let automaticInterval: TimeInterval = 2 * 60
    static let widgetReloadInterval: TimeInterval = 5 * 60

    private static let gate = SyncGate()

    static func bootstrapDemoIfNeeded() {
        if TokenFileStore.load() != nil { return }
        let current = SharedStore.load()
        if current.lists.isEmpty {
            SharedStore.save(SampleData.snapshot())
        }
    }

    static func syncFromGoogle() async throws {
        _ = try await gate.run(force: true, minInterval: 0, reloadWidgets: true)
    }

    @discardableResult
    static func syncFromGoogleIfNeeded(
        minInterval: TimeInterval = automaticInterval,
        reloadWidgets: Bool = true
    ) async -> Bool {
        (try? await gate.run(force: false, minInterval: minInterval, reloadWidgets: reloadWidgets)) ?? false
    }

    static func setCompleted(listId: String, taskId: String, completed: Bool) async {
        SharedStore.mutate { snapshot in
            guard let listIndex = snapshot.lists.firstIndex(where: { $0.id == listId }),
                  let taskIndex = snapshot.lists[listIndex].tasks.firstIndex(where: { $0.id == taskId })
            else { return }
            snapshot.lists[listIndex].tasks[taskIndex].status = completed ? "completed" : "needsAction"
            snapshot.lists[listIndex].tasks[taskIndex].completed = completed ? Date() : nil
        }

        let signedIn = await TokenManager.shared.currentTokens() != nil
        guard GoogleAuthConfig.isConfigured, signedIn else { return }
        do {
            try await GoogleTasksClient.setCompleted(listId: listId, taskId: taskId, completed: completed)
        } catch {
            NSLog("Failed to sync completion to Google: \(error.localizedDescription)")
        }
    }

    static func addTask(listId: String, title: String, notes: String? = nil, due: Date? = nil) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if await TokenManager.shared.currentTokens() != nil, GoogleAuthConfig.isConfigured {
            let created = try await GoogleTasksClient.insertTask(listId: listId, title: trimmed, notes: notes, due: due)
            SharedStore.mutate { snapshot in
                guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }) else { return }
                snapshot.lists[index].tasks.insert(created, at: 0)
            }
        } else {
            let item = TaskItem(
                id: UUID().uuidString,
                listId: listId,
                title: trimmed,
                notes: notes,
                status: "needsAction",
                due: due,
                completed: nil,
                updated: Date(),
                parent: nil,
                position: String(format: "%05d", Int.random(in: 1...99999)),
                webViewLink: nil
            )
            SharedStore.mutate { snapshot in
                guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }) else { return }
                snapshot.lists[index].tasks.insert(item, at: 0)
            }
        }
    }

    static func deleteTask(listId: String, taskId: String) async {
        SharedStore.mutate { snapshot in
            guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }) else { return }
            snapshot.lists[index].tasks.removeAll { $0.id == taskId || $0.parent == taskId }
        }
        let signedIn = await TokenManager.shared.currentTokens() != nil
        guard GoogleAuthConfig.isConfigured, signedIn else { return }
        try? await GoogleTasksClient.deleteTask(listId: listId, taskId: taskId)
    }

    static func renameTask(listId: String, taskId: String, title: String) async {
        SharedStore.mutate { snapshot in
            guard let listIndex = snapshot.lists.firstIndex(where: { $0.id == listId }),
                  let taskIndex = snapshot.lists[listIndex].tasks.firstIndex(where: { $0.id == taskId })
            else { return }
            snapshot.lists[listIndex].tasks[taskIndex].title = title
        }
        let signedIn = await TokenManager.shared.currentTokens() != nil
        guard GoogleAuthConfig.isConfigured, signedIn else { return }
        try? await GoogleTasksClient.updateTitle(listId: listId, taskId: taskId, title: title)
    }
}

/// Serializes Google pulls so the widget, app, and refresh button don't race.
private actor SyncGate {
    private var inFlight: Task<Bool, Error>?

    func run(force: Bool, minInterval: TimeInterval, reloadWidgets: Bool) async throws -> Bool {
        if let inFlight {
            let didSync = try await inFlight.value
            if !force { return didSync }
        }

        guard GoogleAuthConfig.isConfigured, TokenFileStore.load() != nil else {
            return false
        }

        if !force {
            let last = SharedStore.load().lastSyncedAt
            if let last, Date().timeIntervalSince(last) < minInterval {
                return false
            }
        }

        let task = Task<Bool, Error> {
            try await SyncGate.pullAndSave(reloadWidgets: reloadWidgets)
            return true
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private static func pullAndSave(reloadWidgets: Bool) async throws {
        let local = SharedStore.load()
        var remote = try await GoogleTasksClient.fetchAll()
        remote = mergePendingCompletions(remote: remote, local: local)
        SharedStore.save(remote, reloadWidgets: reloadWidgets)
    }

    /// Keep a checkbox the user just tapped if Google hasn't seen the PATCH yet.
    private static func mergePendingCompletions(remote: TasksSnapshot, local: TasksSnapshot) -> TasksSnapshot {
        var remote = remote
        let window = Date().addingTimeInterval(-90)
        for (listIndex, list) in remote.lists.enumerated() {
            guard let localList = local.list(id: list.id) else { continue }
            for (taskIndex, task) in list.tasks.enumerated() {
                guard let localTask = localList.tasks.first(where: { $0.id == task.id }) else { continue }
                let localStamp = localTask.completed ?? localTask.updated ?? .distantPast
                if localTask.isCompleted, !task.isCompleted, localStamp >= window {
                    remote.lists[listIndex].tasks[taskIndex].status = "completed"
                    remote.lists[listIndex].tasks[taskIndex].completed = localTask.completed ?? Date()
                } else if !localTask.isCompleted, task.isCompleted, (localTask.updated ?? .distantPast) >= window {
                    remote.lists[listIndex].tasks[taskIndex].status = "needsAction"
                    remote.lists[listIndex].tasks[taskIndex].completed = nil
                }
            }
        }
        return remote
    }
}
