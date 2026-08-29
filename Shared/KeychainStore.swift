import Foundation

enum TokenFileStore {
    private static var url: URL? {
        AppGroup.containerURL?.appendingPathComponent("oauth-tokens.json")
    }

    static func save(_ tokens: OAuthTokens) throws {
        guard let url else {
            throw GoogleTasksError.oauth("App Group container is unavailable. Check the group.com.googletasks.Tasks entitlement.")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(tokens)
        try data.write(to: url, options: [.atomic])
    }

    static func load() -> OAuthTokens? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    static func delete() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
