import Foundation

enum TokenFileStore {
    static func save(_ tokens: OAuthTokens) throws {
        let urls = AppGroup.tokenCandidates
        guard let first = urls.first else {
            throw GoogleTasksError.oauth("Could not save the Google session.")
        }
        let data = try JSONEncoder().encode(tokens)
        var lastError: Error?
        for url in urls {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                lastError = error
            }
        }
        if (try? Data(contentsOf: first)) == nil, let lastError {
            throw lastError
        }
    }

    static func load() -> OAuthTokens? {
        for url in AppGroup.tokenCandidates {
            if let data = try? Data(contentsOf: url),
               let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) {
                return tokens
            }
        }
        return nil
    }

    static func delete() {
        for url in AppGroup.tokenCandidates {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
