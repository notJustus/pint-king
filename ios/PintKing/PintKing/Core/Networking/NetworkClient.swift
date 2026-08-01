//
//  NetworkClient.swift
//  PintKing
//
//  The single place the app talks to the network. Repositories hand it an
//  Endpoint and get back a decoded value or a typed APIError; everything about
//  tokens — stamping the JWT, refreshing it before it expires, refreshing again
//  when the server says 401, and giving up to a logout — lives here, so no
//  repository ever thinks about authentication (l3-ios-app.md §6).
//
//  It is an `actor` for one specific reason: refresh tokens are single-use and
//  rotate on every call, and the API invalidates the whole token family if an
//  old one is replayed (l3-api.md Property 5). Serialising the refresh decision
//  lets concurrent requests share one in-flight refresh instead of racing to
//  spend the same refresh token twice.
//

import Foundation

actor NetworkClient {

    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStoring

    /// Refresh proactively when the JWT has less than this long to live
    /// (l3-ios-app.md §6: 5 minutes). Injectable so tests don't have to mint
    /// tokens with awkward expiries.
    private let refreshWindow: TimeInterval

    /// The refresh currently in flight, if any. Shared by every caller that
    /// arrives while it runs.
    private var refreshTask: Task<Tokens, Error>?

    /// Called when the session is unrecoverable (refresh failed). The real
    /// AuthRepository hooks this up to clear its state so RootView returns to
    /// Login. Set after construction because the repository is built on top of
    /// this client — the dependency only points one way at init time.
    private var authenticationLostHandler: (@Sendable () async -> Void)?

    init(baseURL: URL,
         session: URLSession = .shared,
         tokenStore: TokenStoring,
         refreshWindow: TimeInterval = 5 * 60) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
        self.refreshWindow = refreshWindow
    }

    func setAuthenticationLostHandler(_ handler: @escaping @Sendable () async -> Void) {
        authenticationLostHandler = handler
    }

    // MARK: - Public API

    /// Performs the request and decodes the response body.
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await perform(endpoint, multipart: nil)
        return try decode(data)
    }

    /// Performs the request and discards the response body — for the 204s
    /// (delete, logout, leave) and any call whose result the caller ignores.
    func request(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint, multipart: nil)
    }

    /// Performs a multipart upload (pint photo, avatar) and decodes the result.
    /// The endpoint supplies the URL and method; the form supplies the body.
    func upload<T: Decodable & Sendable>(_ endpoint: Endpoint, form: MultipartFormData) async throws -> T {
        let data = try await perform(endpoint, multipart: form)
        return try decode(data)
    }

    // MARK: - Request pipeline

    private func perform(_ endpoint: Endpoint, multipart: MultipartFormData?) async throws -> Data {
        if endpoint.requiresAuthentication {
            try await refreshIfExpiring()
        }

        var request = try endpoint.makeRequest(baseURL: baseURL)
        if let multipart {
            request.httpBody = multipart.encoded()
            request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        }

        let response = try await send(request, authenticated: endpoint.requiresAuthentication)

        // Reactive refresh: the token expired between our expiry check and the
        // server's. Refresh once, retry once — a second 401 is a real 401.
        if response.statusCode == 401 && endpoint.requiresAuthentication {
            _ = try await refreshTokens()
            let retry = try await send(request, authenticated: true)
            if let error = APIError.from(statusCode: retry.statusCode) { throw error }
            return retry.data
        }

        if let error = APIError.from(statusCode: response.statusCode) { throw error }
        return response.data
    }

    /// Stamps the current JWT (read at send time, so a retry picks up a freshly
    /// refreshed one) and maps transport failures to `.networkUnavailable`.
    private func send(_ request: URLRequest, authenticated: Bool) async throws -> (data: Data, statusCode: Int) {
        var request = request
        if authenticated, let jwt = tokenStore.load()?.jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.networkUnavailable
            }
            return (data, http.statusCode)
        } catch let error as APIError {
            throw error
        } catch {
            // URLError and anything else the transport throws: no HTTP response
            // came back, so there is no status to map.
            throw APIError.networkUnavailable
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONCoding.decoder.decode(T.self, from: data)
        } catch {
            // A 2xx whose body we can't read is the server breaking its contract.
            throw APIError.serverError
        }
    }

    // MARK: - Token refresh

    /// Proactive refresh: if the stored JWT expires within `refreshWindow`,
    /// renew it before spending a request on a token we already know is stale.
    private func refreshIfExpiring() async throws {
        guard let tokens = tokenStore.load(),
              let expiry = JWTExpiry.expiry(of: tokens.jwt),
              expiry.timeIntervalSinceNow < refreshWindow else {
            return
        }
        _ = try await refreshTokens()
    }

    /// Rotates the token pair, coalescing concurrent callers onto one request.
    /// On failure the session is over: clear the tokens, tell whoever is
    /// listening, and surface `.unauthorized`.
    @discardableResult
    private func refreshTokens() async throws -> Tokens {
        if let inFlight = refreshTask {
            return try await inFlight.value
        }

        let task = Task { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            return try await task.value
        } catch {
            tokenStore.clear()
            await authenticationLostHandler?()
            throw APIError.unauthorized
        }
    }

    private func performRefresh() async throws -> Tokens {
        guard let current = tokenStore.load() else { throw APIError.unauthorized }

        let request = try Endpoint.refresh(refreshToken: current.refreshToken).makeRequest(baseURL: baseURL)
        let response = try await send(request, authenticated: false)
        if let error = APIError.from(statusCode: response.statusCode) { throw error }

        let pair: TokenPairResponse = try decode(response.data)
        let tokens = Tokens(jwt: pair.jwt, refreshToken: pair.refreshToken)
        tokenStore.save(tokens)
        return tokens
    }
}

/// `POST /auth/refresh` response (AuthController.TokenPair).
struct TokenPairResponse: Decodable, Sendable {
    let jwt: String
    let refreshToken: String
}
