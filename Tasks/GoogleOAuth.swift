import AppKit
import CryptoKit
import Foundation
import Network

enum GoogleOAuth {
    static func signIn() async throws -> OAuthTokens {
        guard GoogleAuthConfig.isConfigured else { throw GoogleTasksError.notConfigured }

        let verifier = randomURLSafe(32)
        let challenge = pkceChallenge(verifier)
        let server = LoopbackHTTPServer()
        let port = try await server.start()
        let redirectURI = "http://127.0.0.1:\(port)/oauth2redirect"

        var components = URLComponents(url: GoogleAuthConfig.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleAuthConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else {
            throw GoogleTasksError.oauth("Could not build the Google sign-in URL.")
        }

        await MainActor.run {
            NSWorkspace.shared.open(authURL)
        }

        let code = try await server.waitForCode(timeout: 180)
        return try await exchangeCode(code, redirectURI: redirectURI, verifier: verifier)
    }

    private static func exchangeCode(_ code: String, redirectURI: String, verifier: String) async throws -> OAuthTokens {
        var request = URLRequest(url: GoogleAuthConfig.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded([
            "client_id": GoogleAuthConfig.clientID,
            "client_secret": GoogleAuthConfig.clientSecret,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfFailed(data: data, response: response)
        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        var tokens = OAuthTokens(
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token,
            expiry: Date().addingTimeInterval(TimeInterval(payload.expires_in)),
            tokenType: payload.token_type ?? "Bearer",
            email: nil
        )
        try await TokenManager.shared.save(tokens)
        if let email = try? await GoogleTasksClient.fetchUserEmail() {
            tokens.email = email
            try await TokenManager.shared.save(tokens)
        }
        return tokens
    }

    private static func randomURLSafe(_ byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func pkceChallenge(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Tiny loopback HTTP server for Google's installed-app OAuth redirect.
final class LoopbackHTTPServer: @unchecked Sendable {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?

    func start() async throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !resumed, let port = listener.port?.rawValue else { return }
                    resumed = true
                    continuation.resume(returning: port)
                case .failed(let error):
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
    }

    func waitForCode(timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                self.finish(.failure(GoogleTasksError.oauth("Sign-in timed out. Try again.")))
                throw GoogleTasksError.oauth("Sign-in timed out. Try again.")
            }
            guard let value = try await group.next() else {
                throw GoogleTasksError.oauth("Sign-in failed.")
            }
            group.cancelAll()
            return value
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, error in
            defer { connection.cancel() }
            if let error {
                self?.finish(.failure(error))
                return
            }
            guard let data, let request = String(data: data, encoding: .utf8) else { return }
            let isRedirect = request.contains("/oauth2redirect") || request.contains("code=") || request.contains("error=")
            guard isRedirect else { return }

            let html = """
            <html><body style="font-family:-apple-system;padding:48px;text-align:center">
            <h2>You're signed in</h2>
            <p>You can close this window and return to Tasks.</p>
            </body></html>
            """
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in })

            if let code = Self.code(from: request) {
                self?.finish(.success(code))
            } else if let oauthError = Self.queryValue("error", from: request) {
                self?.finish(.failure(GoogleTasksError.oauth(oauthError.replacingOccurrences(of: "_", with: " "))))
            } else {
                self?.finish(.failure(GoogleTasksError.oauth("Google did not return an authorization code.")))
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        listener?.cancel()
        listener = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(with: result)
        }
    }

    private static func code(from request: String) -> String? {
        queryValue("code", from: request)
    }

    private static func queryValue(_ name: String, from request: String) -> String? {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first ?? Substring(request)
        guard let qIndex = firstLine.firstIndex(of: "?") else { return nil }
        let query = firstLine[firstLine.index(after: qIndex)...]
        let end = query.firstIndex(of: " ") ?? query.endIndex
        let pairs = query[..<end].split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2, parts[0] == name {
                return String(parts[1]).removingPercentEncoding
            }
        }
        return nil
    }
}
