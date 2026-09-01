import Darwin
import Foundation

enum AppGroup {
    static let identifier = "group.com.googletasks.Tasks"
    static let snapshotFilename = "tasks-snapshot.json"
    static let widgetCacheFilename = "widget-cache.json"
    static let tokenFilename = "oauth-tokens.json"
    static let focusedListFilename = "widget-focus.txt"
    static let showingPickerFilename = "widget-showing-picker.txt"
    static let taskPageFilename = "widget-task-page.json"
    static let fadingCompletionsFilename = "widget-fading.json"
    static let showingCompletedFilename = "widget-showing-completed.txt"
    static let pendingComposeFilename = "widget-compose.txt"
    static let selectedListKey = "selectedListId"
    static let widgetSnapshotKey = "widgetSnapshot"
    static let widgetFocusedListKey = "widgetFocusedListId"
    /// Keep the original kind. Changing it made macOS keep a dead “sign in” snapshot.
    static let widgetKind = "TasksListWidget"
    static let widgetKindLegacy = "TasksBoardsWidget"
    static let urlScheme = "googletasks"
    static let composeNotification = Notification.Name("com.googletasks.Tasks.composeNewTask")
    static let snapshotDidChange = Notification.Name("com.googletasks.Tasks.snapshotDidChange")
    static let supportFolder = "com.googletasks.Tasks"

    static func newTaskURL(listId: String) -> URL {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "new"
        components.queryItems = [URLQueryItem(name: "list", value: listId)]
        return components.url ?? URL(string: "\(urlScheme)://new")!
    }

    /// Real user home, not the sandbox container. WidgetKit on macOS denies
    /// App Group UserDefaults even when the entitlement is present.
    static var realHomeURL: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var realGroupURL: URL {
        realHomeURL.appendingPathComponent("Library/Group Containers/\(identifier)", isDirectory: true)
    }

    static var supportURL: URL {
        realHomeURL.appendingPathComponent("Library/Application Support/\(supportFolder)", isDirectory: true)
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) ?? realGroupURL
    }

    static var snapshotCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(snapshotFilename),
            realGroupURL.appendingPathComponent(snapshotFilename),
            supportURL.appendingPathComponent(widgetCacheFilename),
            realGroupURL.appendingPathComponent(widgetCacheFilename),
            containerURL?.appendingPathComponent(snapshotFilename)
        ])
    }

    static var fullSnapshotCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(snapshotFilename),
            realGroupURL.appendingPathComponent(snapshotFilename),
            containerURL?.appendingPathComponent(snapshotFilename)
        ])
    }

    static var tokenCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(tokenFilename),
            realGroupURL.appendingPathComponent(tokenFilename),
            containerURL?.appendingPathComponent(tokenFilename)
        ])
    }

    static var focusedListURL: URL {
        supportURL.appendingPathComponent(focusedListFilename)
    }

    static var showingPickerURL: URL {
        supportURL.appendingPathComponent(showingPickerFilename)
    }

    static var showingPickerCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(showingPickerFilename),
            realGroupURL.appendingPathComponent(showingPickerFilename),
            containerURL?.appendingPathComponent(showingPickerFilename)
        ])
    }

    static var taskPageCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(taskPageFilename),
            realGroupURL.appendingPathComponent(taskPageFilename),
            containerURL?.appendingPathComponent(taskPageFilename)
        ])
    }

    static var fadingCompletionsCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(fadingCompletionsFilename),
            realGroupURL.appendingPathComponent(fadingCompletionsFilename),
            containerURL?.appendingPathComponent(fadingCompletionsFilename)
        ])
    }

    static var showingCompletedCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(showingCompletedFilename),
            realGroupURL.appendingPathComponent(showingCompletedFilename),
            containerURL?.appendingPathComponent(showingCompletedFilename)
        ])
    }

    static var pendingComposeCandidates: [URL] {
        uniqueURLs([
            supportURL.appendingPathComponent(pendingComposeFilename),
            realGroupURL.appendingPathComponent(pendingComposeFilename),
            containerURL?.appendingPathComponent(pendingComposeFilename)
        ])
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    private static func uniqueURLs(_ urls: [URL?]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls.compactMap({ $0 }) {
            if seen.insert(url.path).inserted {
                result.append(url)
            }
        }
        return result
    }
}
