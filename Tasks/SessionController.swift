import AppKit
import SwiftUI

@MainActor
final class SessionController: ObservableObject {
    @Published var snapshot: TasksSnapshot
    @Published var selectedListId: String?
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var isSignedIn = false
    @Published var focusAddField = false
    @Published var showCompleted = true
    @Published var isComposing = false
    @Published var isSigningIn = false
    @Published var hasCompletedOnboarding: Bool
    @Published var showWidgetHint = false
    @Published private(set) var completingIds: Set<String> = []
    private var statusOverrides: [String: Bool] = [:]
    private static let onboardingKey = "hasCompletedOnboarding"
    private let refreshActivity = NSBackgroundActivityScheduler(identifier: "com.googletasks.Tasks.refresh")

    init() {
        SyncService.bootstrapDemoIfNeeded()
        let loaded = SharedStore.load()
        snapshot = loaded
        selectedListId = loaded.selectedListId ?? loaded.lists.first?.id
        let signedIn = TokenFileStore.load() != nil
        isSignedIn = signedIn
        let seenOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        hasCompletedOnboarding = seenOnboarding || signedIn
        if signedIn, !seenOnboarding {
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        }
        if !loaded.lists.isEmpty {
            SharedStore.save(loaded)
        }
        consumePendingCompose()
        startBackgroundRefresh()
    }

    deinit {
        refreshActivity.invalidate()
    }

    private func startBackgroundRefresh() {
        refreshActivity.repeats = true
        refreshActivity.interval = SyncService.widgetReloadInterval
        refreshActivity.tolerance = 30
        refreshActivity.qualityOfService = .utility
        refreshActivity.schedule { [weak self] completion in
            Task { @MainActor in
                await self?.refresh(userInitiated: false)
                completion(.finished)
            }
        }
    }

    var needsOnboarding: Bool { !hasCompletedOnboarding }

    var selectedList: TaskList? {
        guard let selectedListId else { return snapshot.lists.first }
        return snapshot.lists.first(where: { $0.id == selectedListId })
    }

    var isConfigured: Bool { GoogleAuthConfig.isConfigured }

    func select(listId: String) {
        guard selectedListId != listId else { return }
        completingIds = []
        selectedListId = listId
        SharedStore.setSelectedListId(listId)
    }

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "new" {
            let queryId = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "list" })?.value
            beginCompose(listId: queryId ?? parts.first)
            return
        }
        if url.host == "list", let id = parts.first, snapshot.list(id: id) != nil {
            select(listId: id)
        } else if parts.count >= 2, parts[0] == "list" {
            select(listId: parts[1])
        }
    }

    func consumePendingCompose() {
        guard let id = SharedStore.pendingComposeListId() else { return }
        SharedStore.clearPendingCompose()
        beginCompose(listId: id)
    }

    func beginCompose(listId: String?) {
        if let listId, snapshot.list(id: listId) != nil {
            select(listId: listId)
        }
        NSApp.activate(ignoringOtherApps: true)
        isComposing = true
    }

    func isVisuallyCompleted(_ task: TaskItem) -> Bool {
        completingIds.contains(task.id) || (!completingIds.contains("undo-\(task.id)") && task.isCompleted)
    }

    func openTasks(in list: TaskList) -> [TaskItem] {
        let pending = list.completedTasks.filter { completingIds.contains($0.id) }
        return list.incompleteTasks + pending
    }

    func completedTasks(in list: TaskList) -> [TaskItem] {
        list.completedTasks.filter { !completingIds.contains($0.id) }
    }

    func signIn() async {
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }
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

    func signInFromOnboarding() async {
        await signIn()
        if isSignedIn {
            completeOnboarding(showWidgetHint: true)
        }
    }

    func completeOnboarding(showWidgetHint: Bool = false) {
        errorMessage = nil
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        self.showWidgetHint = showWidgetHint && isSignedIn
    }

    func dismissWidgetHint() {
        showWidgetHint = false
    }

    func signOut() {
        Task {
            await TokenManager.shared.clear()
        }
        statusOverrides = [:]
        completingIds = []
        isSignedIn = false
        SharedStore.save(SampleData.snapshot())
        snapshot = SharedStore.load()
        selectedListId = snapshot.selectedListId
    }

    func reloadFromDisk() {
        SharedStore.invalidateCache()
        snapshot = adopt(SharedStore.load())
        isSignedIn = TokenFileStore.load() != nil
        applyKeptSelection(selectedListId)
    }

    func refresh(userInitiated: Bool = true) async {
        guard isSignedIn else {
            snapshot = SharedStore.load()
            return
        }
        if userInitiated {
            isSyncing = true
            errorMessage = nil
        }
        defer {
            if userInitiated { isSyncing = false }
        }
        let keepSelection = selectedListId
        do {
            if userInitiated {
                try await SyncService.syncFromGoogle()
            } else {
                await SyncService.syncFromGoogleIfNeeded()
            }
            snapshot = adopt(SharedStore.load())
            applyKeptSelection(keepSelection)
        } catch {
            if userInitiated {
                errorMessage = error.localizedDescription
            }
            snapshot = adopt(SharedStore.load())
        }
    }

    private func applyKeptSelection(_ keepSelection: String?) {
        if let keepSelection, snapshot.list(id: keepSelection) != nil {
            selectedListId = keepSelection
            snapshot.selectedListId = keepSelection
        } else if selectedListId == nil || snapshot.list(id: selectedListId ?? "") == nil {
            selectedListId = snapshot.selectedListId ?? snapshot.lists.first?.id
        }
    }

    func toggle(_ task: TaskItem) {
        let completing = !isVisuallyCompleted(task)
        statusOverrides[task.id] = completing
        withAnimation(.easeInOut(duration: 0.32)) {
            if completing {
                completingIds.insert(task.id)
                completingIds.remove("undo-\(task.id)")
            } else {
                completingIds.insert("undo-\(task.id)")
                completingIds.remove(task.id)
            }
            applyStatus(taskId: task.id, listId: task.listId, completed: completing)
        }
        Task {
            await SyncService.setCompleted(listId: task.listId, taskId: task.id, completed: completing)
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.easeInOut(duration: 0.25)) {
                completingIds.remove(task.id)
                completingIds.remove("undo-\(task.id)")
            }
        }
    }

    func addTask(title: String, notes: String? = nil, due: Date? = nil) async {
        guard let listId = selectedList?.id else { return }
        do {
            try await SyncService.addTask(listId: listId, title: title, notes: notes, due: due)
            snapshot = adopt(SharedStore.load())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: TaskItem) async {
        statusOverrides[task.id] = nil
        completingIds.remove(task.id)
        completingIds.remove("undo-\(task.id)")
        await SyncService.deleteTask(listId: task.listId, taskId: task.id)
        snapshot = adopt(SharedStore.load())
    }

    func rename(_ task: TaskItem, title: String) async {
        await SyncService.renameTask(listId: task.listId, taskId: task.id, title: title)
        snapshot = adopt(SharedStore.load())
    }

    private func adopt(_ loaded: TasksSnapshot) -> TasksSnapshot {
        var loaded = loaded
        var remaining: [String: Bool] = [:]
        for (id, completed) in statusOverrides {
            let alreadyMatches = loaded.lists.contains { list in
                list.tasks.contains { $0.id == id && $0.isCompleted == completed }
            }
            if alreadyMatches { continue }
            remaining[id] = completed
            applyStatus(to: &loaded, taskId: id, completed: completed)
        }
        statusOverrides = remaining
        return loaded
    }

    private func applyStatus(taskId: String, listId: String, completed: Bool) {
        var next = snapshot
        applyStatus(to: &next, taskId: taskId, listId: listId, completed: completed)
        snapshot = next
    }

    private func applyStatus(to snapshot: inout TasksSnapshot, taskId: String, listId: String? = nil, completed: Bool) {
        let listIndex = listId.flatMap { id in snapshot.lists.firstIndex(where: { $0.id == id }) }
            ?? snapshot.lists.firstIndex(where: { list in list.tasks.contains { $0.id == taskId } })
        guard let listIndex,
              let taskIndex = snapshot.lists[listIndex].tasks.firstIndex(where: { $0.id == taskId })
        else { return }
        snapshot.lists[listIndex].tasks[taskIndex].status = completed ? "completed" : "needsAction"
        snapshot.lists[listIndex].tasks[taskIndex].completed = completed ? Date() : nil
    }
}
