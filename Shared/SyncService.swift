import Foundation
import WidgetKit

enum SyncService {
    static func bootstrapDemoIfNeeded() {
        let current = SharedStore.load()
        if current.lists.isEmpty {
            SharedStore.save(SampleData.snapshot())
        }
    }

    static func syncFromGoogle() async throws {
        let snapshot = try await GoogleTasksClient.fetchAll()
        SharedStore.save(snapshot)
    }

    static func setCompleted(listId: String, taskId: String, completed: Bool) async {
        SharedStore.mutate { snapshot in
            guard let listIndex = snapshot.lists.firstIndex(where: { $0.id == listId }),
                  let taskIndex = snapshot.lists[listIndex].tasks.firstIndex(where: { $0.id == taskId })
            else { return }
            snapshot.lists[listIndex].tasks[taskIndex].status = completed ? "completed" : "needsAction"
            snapshot.lists[listIndex].tasks[taskIndex].completed = completed ? Date() : nil
        }
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)

        let signedIn = await TokenManager.shared.currentTokens() != nil
        guard GoogleAuthConfig.isConfigured, signedIn else { return }
        do {
            try await GoogleTasksClient.setCompleted(listId: listId, taskId: taskId, completed: completed)
        } catch {
            NSLog("Failed to sync completion to Google: \(error.localizedDescription)")
        }
    }

    static func addTask(listId: String, title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if await TokenManager.shared.currentTokens() != nil, GoogleAuthConfig.isConfigured {
            let created = try await GoogleTasksClient.insertTask(listId: listId, title: trimmed)
            SharedStore.mutate { snapshot in
                guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }) else { return }
                snapshot.lists[index].tasks.insert(created, at: 0)
            }
        } else {
            let item = TaskItem(
                id: UUID().uuidString,
                listId: listId,
                title: trimmed,
                notes: nil,
                status: "needsAction",
                due: nil,
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
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
    }

    static func deleteTask(listId: String, taskId: String) async {
        SharedStore.mutate { snapshot in
            guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }) else { return }
            snapshot.lists[index].tasks.removeAll { $0.id == taskId || $0.parent == taskId }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
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
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
        let signedIn = await TokenManager.shared.currentTokens() != nil
        guard GoogleAuthConfig.isConfigured, signedIn else { return }
        try? await GoogleTasksClient.updateTitle(listId: listId, taskId: taskId, title: title)
    }
}
