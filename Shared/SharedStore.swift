import Foundation
import WidgetKit

enum SharedStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private static let lock = NSLock()
    private static var cached: TasksSnapshot?
    private static var persistGeneration = 0
    private static let persistQueue = DispatchQueue(label: "com.googletasks.Tasks.store", qos: .utility)

    static func invalidateCache() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    static func load() -> TasksSnapshot {
        lock.lock()
        if let cached {
            let snapshot = cached
            lock.unlock()
            return applyPersistedSelection(snapshot)
        }
        lock.unlock()

        var loaded: TasksSnapshot?
        for url in AppGroup.fullSnapshotCandidates {
            if let snapshot = decodeSnapshot(at: url), !snapshot.lists.isEmpty {
                loaded = snapshot
                break
            }
        }
        let snapshot = applyPersistedSelection(loaded ?? loadForWidget())
        lock.lock()
        if cached == nil {
            cached = snapshot
        }
        let result = cached ?? snapshot
        lock.unlock()
        return applyPersistedSelection(result)
    }

    static func loadForWidget() -> TasksSnapshot {
        lock.lock()
        if let cached, !cached.lists.isEmpty {
            let snapshot = cached.compactedForWidget()
            lock.unlock()
            return applyPersistedSelection(snapshot)
        }
        lock.unlock()

        for url in AppGroup.snapshotCandidates {
            if let snapshot = decodeSnapshot(at: url), !snapshot.lists.isEmpty {
                return snapshot
            }
        }
        return .empty
    }

    static func focusedListId() -> String? {
        if let value = try? String(contentsOf: AppGroup.focusedListURL, encoding: .utf8) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return AppGroup.sharedDefaults?.string(forKey: AppGroup.widgetFocusedListKey)
    }

    static func setFocusedListId(_ id: String?) {
        try? FileManager.default.createDirectory(at: AppGroup.supportURL, withIntermediateDirectories: true)
        if let id, !id.isEmpty {
            try? id.write(to: AppGroup.focusedListURL, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: AppGroup.focusedListURL)
        }
        AppGroup.sharedDefaults?.set(id, forKey: AppGroup.widgetFocusedListKey)
        reloadWidgets()
    }

    static func isShowingPicker() -> Bool {
        for url in AppGroup.showingPickerCandidates {
            if let value = try? String(contentsOf: url, encoding: .utf8),
               value.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                return true
            }
        }
        return AppGroup.sharedDefaults?.bool(forKey: AppGroup.showingPickerFilename) ?? false
    }

    static func setShowingPicker(_ show: Bool) {
        try? FileManager.default.createDirectory(at: AppGroup.supportURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: AppGroup.realGroupURL, withIntermediateDirectories: true)
        if show {
            for url in AppGroup.showingPickerCandidates {
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try "1".write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    NSLog("SharedStore picker flag write failed \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            AppGroup.sharedDefaults?.set(true, forKey: AppGroup.showingPickerFilename)
        } else {
            for url in AppGroup.showingPickerCandidates {
                try? FileManager.default.removeItem(at: url)
            }
            AppGroup.sharedDefaults?.removeObject(forKey: AppGroup.showingPickerFilename)
        }
        reloadWidgets()
    }

    static func taskPageOffset(for listId: String) -> Int {
        max(0, pageOffsets()[listId] ?? 0)
    }

    static func setTaskPageOffset(_ offset: Int, for listId: String) {
        var pages = pageOffsets()
        if offset <= 0 {
            pages.removeValue(forKey: listId)
        } else {
            pages[listId] = offset
        }
        writePageOffsets(pages)
        reloadWidgets()
    }

    static func advanceTaskPage(listId: String, pageSize: Int, totalCount: Int, step: Int) {
        let size = max(1, pageSize)
        let total = max(0, totalCount)
        guard total > 0 else {
            setTaskPageOffset(0, for: listId)
            return
        }
        let current = taskPageOffset(for: listId)
        var next = current + step * size
        if next >= total {
            next = 0
        } else if next < 0 {
            let lastPage = ((total - 1) / size) * size
            next = lastPage
        }
        setTaskPageOffset(next, for: listId)
    }

    private static func pageOffsets() -> [String: Int] {
        for url in AppGroup.taskPageCandidates {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
                return decoded
            }
        }
        return [:]
    }

    private static func writePageOffsets(_ pages: [String: Int]) {
        let data = try? JSONEncoder().encode(pages)
        if pages.isEmpty {
            for url in AppGroup.taskPageCandidates {
                try? FileManager.default.removeItem(at: url)
            }
            return
        }
        guard let data else { return }
        for url in AppGroup.taskPageCandidates {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("SharedStore task page write failed \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    static let fadeDuration: TimeInterval = 1.15

    static func markFadingCompletion(_ task: TaskItem) {
        var items = allFadingCompletions()
        items.removeAll { $0.task.id == task.id }
        var completed = task
        completed.status = "completed"
        completed.completed = Date()
        items.append(FadingCompletion(task: completed, completedAt: Date()))
        writeFadingCompletions(items)
    }

    static func clearFadingCompletion(id: String) {
        var items = allFadingCompletions()
        items.removeAll { $0.task.id == id }
        writeFadingCompletions(items)
    }

    static func fadingCompletions(visibleAt date: Date, listId: String) -> [TaskItem] {
        allFadingCompletions()
            .filter { $0.task.listId == listId && date.timeIntervalSince($0.completedAt) < fadeDuration }
            .map(\.task)
    }

    static func hasFadingCompletions(at date: Date) -> Bool {
        allFadingCompletions().contains { date.timeIntervalSince($0.completedAt) < fadeDuration }
    }

    private static func allFadingCompletions() -> [FadingCompletion] {
        for url in AppGroup.fadingCompletionsCandidates {
            if let data = try? Data(contentsOf: url),
               let decoded = try? decoder.decode([FadingCompletion].self, from: data) {
                return decoded
            }
        }
        return []
    }

    private static func writeFadingCompletions(_ items: [FadingCompletion]) {
        let pruned = items.filter { Date().timeIntervalSince($0.completedAt) < 30 }
        if pruned.isEmpty {
            for url in AppGroup.fadingCompletionsCandidates {
                try? FileManager.default.removeItem(at: url)
            }
            return
        }
        guard let data = try? encoder.encode(pruned) else { return }
        for url in AppGroup.fadingCompletionsCandidates {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("SharedStore fading write failed \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    static func isShowingCompleted() -> Bool {
        for url in AppGroup.showingCompletedCandidates {
            if let value = try? String(contentsOf: url, encoding: .utf8),
               value.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                return true
            }
        }
        return false
    }

    static func setShowingCompleted(_ show: Bool) {
        if show {
            writeText("1", to: AppGroup.showingCompletedCandidates)
        } else {
            for url in AppGroup.showingCompletedCandidates {
                try? FileManager.default.removeItem(at: url)
            }
        }
        reloadWidgets()
    }

    static func pendingComposeListId() -> String? {
        for url in AppGroup.pendingComposeCandidates {
            if let value = try? String(contentsOf: url, encoding: .utf8) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    static func setPendingCompose(listId: String) {
        writeText(listId, to: AppGroup.pendingComposeCandidates)
    }

    static func clearPendingCompose() {
        for url in AppGroup.pendingComposeCandidates {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func writeText(_ text: String, to urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("SharedStore write failed \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    static func save(_ snapshot: TasksSnapshot, reloadWidgets reload: Bool = true) {
        let snapshot = applyPersistedSelection(snapshot)
        lock.lock()
        cached = snapshot
        persistGeneration += 1
        let generation = persistGeneration
        lock.unlock()
        persistQueue.async {
            lock.lock()
            let latest = persistGeneration
            lock.unlock()
            guard generation == latest else { return }
            persistToDisk(snapshot)
            notifySnapshotChanged()
            if reload {
                reloadWidgets()
            }
        }
    }

    private static func persistToDisk(_ snapshot: TasksSnapshot) {
        let compact = snapshot.compactedForWidget()
        let fullData = try? encoder.encode(snapshot)
        let compactData = try? encoder.encode(compact)

        func write(_ data: Data, to url: URL) {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("SharedStore save failed \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if let fullData {
            write(fullData, to: AppGroup.realGroupURL.appendingPathComponent(AppGroup.snapshotFilename))
            write(fullData, to: AppGroup.supportURL.appendingPathComponent(AppGroup.snapshotFilename))
        }
        if let compactData {
            write(compactData, to: AppGroup.realGroupURL.appendingPathComponent(AppGroup.widgetCacheFilename))
            write(compactData, to: AppGroup.supportURL.appendingPathComponent(AppGroup.widgetCacheFilename))
            AppGroup.sharedDefaults?.set(compactData, forKey: AppGroup.widgetSnapshotKey)
        }
        AppGroup.sharedDefaults?.set(snapshot.selectedListId, forKey: AppGroup.selectedListKey)
    }

    /// Persist the current list without rewriting the full snapshot or reloading widgets.
    static func setSelectedListId(_ id: String) {
        AppGroup.sharedDefaults?.set(id, forKey: AppGroup.selectedListKey)
        writeText(id, to: [
            AppGroup.supportURL.appendingPathComponent("selected-list.txt"),
            AppGroup.realGroupURL.appendingPathComponent("selected-list.txt")
        ])
    }

    static func persistedSelectedListId() -> String? {
        if let value = AppGroup.sharedDefaults?.string(forKey: AppGroup.selectedListKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
        for url in [
            AppGroup.supportURL.appendingPathComponent("selected-list.txt"),
            AppGroup.realGroupURL.appendingPathComponent("selected-list.txt")
        ] {
            if let value = try? String(contentsOf: url, encoding: .utf8) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func applyPersistedSelection(_ snapshot: TasksSnapshot) -> TasksSnapshot {
        var snapshot = snapshot
        if let id = persistedSelectedListId(), snapshot.list(id: id) != nil {
            snapshot.selectedListId = id
        }
        return snapshot
    }

    private static func decodeSnapshot(at url: URL) -> TasksSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(TasksSnapshot.self, from: data)
    }

    static func reloadWidgets() {
        let reload = {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKindLegacy)
            WidgetCenter.shared.reloadAllTimelines()
        }
        if Thread.isMainThread {
            reload()
        } else {
            DispatchQueue.main.async(execute: reload)
        }
    }

    private static func notifySnapshotChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            AppGroup.snapshotDidChange,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func mutate(_ transform: (inout TasksSnapshot) -> Void) {
        lock.lock()
        var current = cached
        lock.unlock()
        if current == nil {
            current = load()
        }
        var snapshot = applyPersistedSelection(current ?? .empty)
        transform(&snapshot)
        save(snapshot)
    }
}
