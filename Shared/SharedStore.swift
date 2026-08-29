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

    static func load() -> TasksSnapshot {
        guard let url = AppGroup.snapshotURL, let data = try? Data(contentsOf: url) else {
            return .empty
        }
        return (try? decoder.decode(TasksSnapshot.self, from: data)) ?? .empty
    }

    static func save(_ snapshot: TasksSnapshot) {
        guard let url = AppGroup.snapshotURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            AppGroup.sharedDefaults.set(snapshot.selectedListId, forKey: AppGroup.selectedListKey)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
        } catch {
            NSLog("SharedStore save failed: \(error.localizedDescription)")
        }
    }

    static func mutate(_ transform: (inout TasksSnapshot) -> Void) {
        var snapshot = load()
        transform(&snapshot)
        save(snapshot)
    }
}
