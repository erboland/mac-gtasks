import Foundation

/// Fill these in from Google Cloud Console → APIs & Services → Credentials.
/// Create an OAuth 2.0 Client ID of type **Desktop app**, enable the Tasks API,
/// then paste the client ID and secret below.
enum GoogleAuthConfig {
    /// Example: `123456789-abcdef.apps.googleusercontent.com`
    static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    /// Desktop OAuth clients include a client secret. It is not a server secret;
    /// it is required for the token exchange on installed apps.
    static let clientSecret = "YOUR_CLIENT_SECRET"

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
