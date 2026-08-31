import Foundation

/// OAuth endpoints and scopes. Put your client ID and secret in
/// `GoogleAuthSecrets.swift` (copy from `GoogleAuthSecrets.example.swift`).
enum GoogleAuthConfig {
    static var clientID: String { GoogleAuthSecrets.clientID }
    static var clientSecret: String { GoogleAuthSecrets.clientSecret }

    static let scopes = [
        "https://www.googleapis.com/auth/tasks",
        "https://www.googleapis.com/auth/userinfo.email"
    ]

    static var isConfigured: Bool {
        !clientID.hasPrefix("YOUR_") && !clientID.isEmpty
            && !clientSecret.hasPrefix("YOUR_") && !clientSecret.isEmpty
    }

    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
    static let tasksAPIBase = URL(string: "https://tasks.googleapis.com/tasks/v1")!
}
