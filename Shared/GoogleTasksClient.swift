import Foundation

enum GoogleTasksClient {
    private static let decoder = JSONDecoder()

    static func fetchUserEmail() async throws -> String? {
        let request = try await authorizedRequest(url: GoogleAuthConfig.userInfoEndpoint)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)
        return try JSONDecoder().decode(UserInfo.self, from: data).email
    }

    static func fetchAll() async throws -> TasksSnapshot {
        let lists = try await fetchTaskLists()
        var hydrated: [TaskList] = []
        for list in lists {
            let tasks = try await fetchTasks(listId: list.id)
            hydrated.append(TaskList(id: list.id, title: list.title ?? "Untitled", updated: DateParser.date(list.updated), tasks: tasks))
        }
        let emailFromProfile = try? await fetchUserEmail()
        let emailFromTokens = await TokenManager.shared.currentTokens()?.email
        let email = emailFromProfile ?? emailFromTokens
        let previous = SharedStore.load().selectedListId
        return TasksSnapshot(
            accountEmail: email,
            isDemo: false,
            lists: hydrated,
            selectedListId: previous ?? hydrated.first?.id,
            lastSyncedAt: Date()
        )
    }

    static func fetchTaskLists() async throws -> [GTaskList] {
        var items: [GTaskList] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(url: GoogleAuthConfig.tasksAPIBase.appending(path: "users/@me/lists"), resolvingAgainstBaseURL: false)!
            var query = [URLQueryItem(name: "maxResults", value: "100")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            let request = try await authorizedRequest(url: components.url!)
            let (data, response) = try await URLSession.shared.data(for: request)
            try throwIfFailed(data: data, response: response)
            let payload = try decoder.decode(GTaskLists.self, from: data)
            items.append(contentsOf: payload.items ?? [])
            pageToken = payload.nextPageToken
        } while pageToken != nil
        return items
    }

    static func fetchTasks(listId: String) async throws -> [TaskItem] {
        var items: [TaskItem] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(
                url: GoogleAuthConfig.tasksAPIBase.appending(path: "lists/\(listId)/tasks"),
                resolvingAgainstBaseURL: false
            )!
            var query = [
                URLQueryItem(name: "maxResults", value: "100"),
                URLQueryItem(name: "showCompleted", value: "true"),
                URLQueryItem(name: "showHidden", value: "false")
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            let request = try await authorizedRequest(url: components.url!)
            let (data, response) = try await URLSession.shared.data(for: request)
            try throwIfFailed(data: data, response: response)
            let payload = try decoder.decode(GTasks.self, from: data)
            for remote in payload.items ?? [] {
                guard remote.deleted != true else { continue }
                items.append(
                    TaskItem(
                        id: remote.id,
                        listId: listId,
                        title: remote.title ?? "",
                        notes: remote.notes,
                        status: remote.status ?? "needsAction",
                        due: DateParser.date(remote.due),
                        completed: DateParser.date(remote.completed),
                        updated: DateParser.date(remote.updated),
                        parent: remote.parent,
                        position: remote.position ?? "",
                        webViewLink: remote.webViewLink
                    )
                )
            }
            pageToken = payload.nextPageToken
        } while pageToken != nil
        return items.sorted { $0.position < $1.position }
    }

    static func setCompleted(listId: String, taskId: String, completed: Bool) async throws {
        let url = GoogleAuthConfig.tasksAPIBase.appending(path: "lists/\(listId)/tasks/\(taskId)")
        let payload = ["status": completed ? "completed" : "needsAction"]
        let body = try JSONEncoder().encode(payload)
        let request = try await authorizedRequest(url: url, method: "PATCH", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)
    }

    static func insertTask(listId: String, title: String, notes: String? = nil, due: Date? = nil) async throws -> TaskItem {
        let url = GoogleAuthConfig.tasksAPIBase.appending(path: "lists/\(listId)/tasks")
        var payload: [String: String] = ["title": title]
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        if let due {
            payload["due"] = DateFormatter.rfc3339Day.string(from: due) + "T00:00:00.000Z"
        }
        let body = try JSONEncoder().encode(payload)
        let request = try await authorizedRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)
        let remote = try decoder.decode(GTask.self, from: data)
        return TaskItem(
            id: remote.id,
            listId: listId,
            title: remote.title ?? title,
            notes: remote.notes,
            status: remote.status ?? "needsAction",
            due: DateParser.date(remote.due),
            completed: DateParser.date(remote.completed),
            updated: DateParser.date(remote.updated),
            parent: remote.parent,
            position: remote.position ?? "",
            webViewLink: remote.webViewLink
        )
    }

    static func deleteTask(listId: String, taskId: String) async throws {
        let url = GoogleAuthConfig.tasksAPIBase.appending(path: "lists/\(listId)/tasks/\(taskId)")
        let request = try await authorizedRequest(url: url, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 204 { return }
        try throwIfFailed(data: data, response: response)
    }

    static func updateTitle(listId: String, taskId: String, title: String) async throws {
        let url = GoogleAuthConfig.tasksAPIBase.appending(path: "lists/\(listId)/tasks/\(taskId)")
        let body = try JSONEncoder().encode(["title": title])
        let request = try await authorizedRequest(url: url, method: "PATCH", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)
    }
}

struct UserInfo: Decodable {
    var email: String?
}

struct GTaskLists: Decodable {
    var items: [GTaskList]?
    var nextPageToken: String?
}

struct GTaskList: Decodable {
    var id: String
    var title: String?
    var updated: String?
}

struct GTasks: Decodable {
    var items: [GTask]?
    var nextPageToken: String?
}

struct GTask: Decodable {
    var id: String
    var title: String?
    var notes: String?
    var status: String?
    var due: String?
    var completed: String?
    var updated: String?
    var parent: String?
    var position: String?
    var deleted: Bool?
    var webViewLink: String?
}

extension ISO8601DateFormatter {
    static let internet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum DateParser {
    static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: raw) { return date }
        if let date = ISO8601DateFormatter.internet.date(from: raw) { return date }
        return DateFormatter.rfc3339Day.date(from: String(raw.prefix(10)))
    }
}

extension DateFormatter {
    static let rfc3339Day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
