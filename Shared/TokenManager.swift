import Foundation

enum GoogleTasksError: LocalizedError {
    case notSignedIn
    case notConfigured
    case http(Int, String)
    case decoding
    case oauth(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in with Google to sync your tasks."
        case .notConfigured:
            return "Add your Google OAuth client ID and secret in GoogleAuthConfig.swift."
        case .http(let code, let body):
            return "Google Tasks request failed (\(code)): \(body)"
        case .decoding:
            return "Could not read the Google Tasks response."
        case .oauth(let message):
            return message
        }
    }
}

actor TokenManager {
    static let shared = TokenManager()

    private var cached: OAuthTokens?

    func currentTokens() -> OAuthTokens? {
        if let cached { return cached }
        let loaded = TokenFileStore.load()
        cached = loaded
        return loaded
    }

    func save(_ tokens: OAuthTokens) throws {
        try TokenFileStore.save(tokens)
        cached = tokens
    }

    func clear() {
        TokenFileStore.delete()
        cached = nil
    }

    func validAccessToken() async throws -> String {
        guard var tokens = currentTokens() else { throw GoogleTasksError.notSignedIn }
        if tokens.isExpired {
            tokens = try await refresh(tokens)
            try save(tokens)
        }
        return tokens.accessToken
    }

    private func refresh(_ tokens: OAuthTokens) async throws -> OAuthTokens {
        guard let refreshToken = tokens.refreshToken, !refreshToken.isEmpty else {
            throw GoogleTasksError.oauth("Session expired. Sign in again.")
        }
        var request = URLRequest(url: GoogleAuthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": GoogleAuthConfig.clientID,
            "client_secret": GoogleAuthConfig.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = formURLEncoded(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuthTokens(
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token ?? refreshToken,
            expiry: Date().addingTimeInterval(TimeInterval(payload.expires_in)),
            tokenType: payload.token_type ?? "Bearer",
            email: tokens.email
        )
    }
}

struct TokenResponse: Decodable {
    var access_token: String
    var expires_in: Int
    var refresh_token: String?
    var token_type: String?
    var id_token: String?
    var scope: String?
}

func formURLEncoded(_ fields: [String: String]) -> Data {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    let pairs = fields.map { key, value in
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(encodedKey)=\(encodedValue)"
    }
    return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
}

func throwIfFailed(data: Data, response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw GoogleTasksError.http(http.statusCode, body)
    }
}

func authorizedRequest(url: URL, method: String = "GET", body: Data? = nil) async throws -> URLRequest {
    let token = try await TokenManager.shared.validAccessToken()
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return request
}
