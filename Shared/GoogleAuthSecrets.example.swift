import Foundation

/// Copy this file to `GoogleAuthSecrets.swift` and paste your Desktop OAuth client.
/// `GoogleAuthSecrets.swift` is gitignored — never commit real credentials.
///
/// Google Cloud Console → APIs & Services → Credentials → Create OAuth client ID
/// → Application type: **Desktop app**. Enable the Google Tasks API.
enum GoogleAuthSecrets {
    static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
    static let clientSecret = "YOUR_CLIENT_SECRET"
}
