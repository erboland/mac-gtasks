import AppKit
import SwiftUI
import WidgetKit

@MainActor
final class SessionController: ObservableObject {
    @Published var snapshot: TasksSnapshot
    @Published var selectedListId: String?
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var isSignedIn = false
    @Published var focusAddField = false
    @Published var showCompleted = true

    init() {
        SyncService.bootstrapDemoIfNeeded()
        let loaded = SharedStore.load()
        snapshot = loaded
        selectedListId = loaded.selectedListId ?? loaded.lists.first?.id
        isSignedIn = TokenFileStore.load() != nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    var selectedList: TaskList? {
        snapshot.lists.first(where: { $0.id == selectedListId }) ?? snapshot.lists.first
    }

    var isConfigured: Bool { GoogleAuthConfig.isConfigured }

    func select(listId: String) {
        selectedListId = listId
        SharedStore.mutate { $0.selectedListId = listId }
        snapshot = SharedStore.load()
    }

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "list", let id = parts.first, snapshot.list(id: id) != nil {
            select(listId: id)
        } else if parts.count >= 2, parts[0] == "list" {
            select(listId: parts[1])
        }
    }

    func signIn() async {
        errorMessage = nil
        do {
            _ = try await GoogleOAuth.signIn()
            isSignedIn = true
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        Task {
            await TokenManager.shared.clear()
        }
        isSignedIn = false
        SharedStore.save(SampleData.snapshot())
        snapshot = SharedStore.load()
        selectedListId = snapshot.selectedListId
    }

    func refresh() async {
        guard isSignedIn else {
            snapshot = SharedStore.load()
            return
        }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            try await SyncService.syncFromGoogle()
            snapshot = SharedStore.load()
            if selectedListId == nil || snapshot.list(id: selectedListId ?? "") == nil {
                selectedListId = snapshot.selectedListId ?? snapshot.lists.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            snapshot = SharedStore.load()
        }
    }

    func toggle(_ task: TaskItem) async {
        await SyncService.setCompleted(listId: task.listId, taskId: task.id, completed: !task.isCompleted)
        snapshot = SharedStore.load()
    }

    func addTask(title: String) async {
        guard let listId = selectedList?.id else { return }
        do {
            try await SyncService.addTask(listId: listId, title: title)
            snapshot = SharedStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: TaskItem) async {
        await SyncService.deleteTask(listId: task.listId, taskId: task.id)
        snapshot = SharedStore.load()
    }

    func rename(_ task: TaskItem, title: String) async {
        await SyncService.renameTask(listId: task.listId, taskId: task.id, title: title)
        snapshot = SharedStore.load()
    }
}
