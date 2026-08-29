import Foundation

enum AppGroup {
    static let identifier = "group.com.googletasks.Tasks"
    static let snapshotFilename = "tasks-snapshot.json"
    static let selectedListKey = "selectedListId"
    static let widgetKind = "TasksListWidget"
    static let urlScheme = "googletasks"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFilename)
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
