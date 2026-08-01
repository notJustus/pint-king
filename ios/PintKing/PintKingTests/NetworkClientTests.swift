//
//  NetworkClientTests.swift
//  PintKingTests
//
//  Task 26: the JWT interceptor. Every test drives a real NetworkClient over a
//  real URLSession whose transport is StubURLProtocol, so header injection,
//  request construction, and decoding are all genuinely exercised — only the
//  server is fake.
//
//  The suite is `.serialized` because StubURLProtocol's handler and recording
//  are process-global (URLSession instantiates the protocol itself, so there is
//  nowhere else to put them); Swift Testing would otherwise run these cases in
//  parallel and let them overwrite each other's stubs.
//

import Foundation
import Testing
@testable import PintKing

@Suite(.serialized)
struct NetworkClientTests {

    let baseURL = URL(string: "https://api.pintking.test")!

    /// A group list payload — small, and a real model, so decoding is tested too.
    static let groupJSON = """
    [{"id":"\(UUID().uuidString)","name":"Sunday Club","inviteCode":"ABCD1234","role":"admin","memberCount":4}]
    """

    /// Long-lived token: far outside the 5-minute proactive-refresh window.
    private func freshTokens(label: String = "current") -> Tokens {
        Tokens(jwt: TestJWT.token(expiringIn: 3600, label: label), refreshToken: "refresh-\(label)")
    }

    private func makeClient(store: TokenStoring) -> NetworkClient {
        NetworkClient(baseURL: baseURL, session: StubURLProtocol.makeSession(), tokenStore: store)
    }

    /// Records that the "session is over" hook fired.
    private actor LogoutSpy {
        private(set) var callCount = 0
        func record() { callCount += 1 }
    }

    // MARK: - JWT injection

    @Test func jwtIsInjectedOnEveryAuthenticatedRequest() async throws {
        let tokens = freshTokens()
        let store = InMemoryTokenStore(tokens: tokens)
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .json(Self.groupJSON) }

        let _: [GroupSummary] = try await client.request(.listGroups)

        let sent = try #require(StubURLProtocol.recordedRequests.first)
        #expect(sent.authorizationHeader == "Bearer \(tokens.jwt)")
    }

    @Test func unauthenticatedEndpointsCarryNoToken() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .json(#"{"jwt":"j","refreshToken":"r","isNewUser":false}"#) }

        let _: TokenPairResponse = try await client.request(.appleAuth(identityToken: "apple-token"))

        let sent = try #require(StubURLProtocol.recordedRequests.first)
        #expect(sent.authorizationHeader == nil)
    }

    @Test func requestWithoutAResponseBodySucceedsOn204() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in Response(statusCode: 204) }

        try await client.request(.deletePint(id: UUID()))

        #expect(StubURLProtocol.recordedRequests.count == 1)
        #expect(StubURLProtocol.recordedRequests.first?.request.httpMethod == "DELETE")
    }

    // MARK: - Reactive refresh (401)

    @Test func unauthorizedTriggersRefreshThenRetriesWithTheNewToken() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        let newJWT = TestJWT.token(expiringIn: 3600, label: "rotated")

        StubURLProtocol.respond { request in
            switch request.url?.path {
            case "/auth/refresh":
                return .json(#"{"jwt":"\#(newJWT)","refreshToken":"refresh-rotated"}"#)
            default:
                // First attempt is stale; the retry succeeds.
                return StubURLProtocol.requestCount(forPath: "/groups") == 1
                    ? Response(statusCode: 401)
                    : .json(Self.groupJSON)
            }
        }

        let groups: [GroupSummary] = try await client.request(.listGroups)

        #expect(groups.count == 1)
        let paths = StubURLProtocol.recordedRequests.map(\.path)
        #expect(paths == ["/groups", "/auth/refresh", "/groups"])
        #expect(StubURLProtocol.recordedRequests.last?.authorizationHeader == "Bearer \(newJWT)")
        #expect(store.load()?.refreshToken == "refresh-rotated")
    }

    @Test func refreshRequestSendsTheStoredRefreshTokenAndNoJWT() async throws {
        let tokens = freshTokens()
        let store = InMemoryTokenStore(tokens: tokens)
        let client = makeClient(store: store)

        StubURLProtocol.respond { request in
            request.url?.path == "/auth/refresh"
                ? .json(#"{"jwt":"\#(TestJWT.token(expiringIn: 3600))","refreshToken":"next"}"#)
                : (StubURLProtocol.requestCount(forPath: "/groups") == 1
                    ? Response(statusCode: 401)
                    : .json(Self.groupJSON))
        }

        let _: [GroupSummary] = try await client.request(.listGroups)

        let refresh = try #require(StubURLProtocol.recordedRequests.first { $0.path == "/auth/refresh" })
        #expect(refresh.authorizationHeader == nil)
        #expect(refresh.bodyString.contains(tokens.refreshToken))
    }

    @Test func aSecondUnauthorizedAfterRetryIsSurfaced() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)

        StubURLProtocol.respond { request in
            request.url?.path == "/auth/refresh"
                ? .json(#"{"jwt":"\#(TestJWT.token(expiringIn: 3600))","refreshToken":"next"}"#)
                : Response(statusCode: 401)   // never recovers
        }

        await #expect(throws: APIError.unauthorized) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }
        // One refresh only: the retry is not retried.
        #expect(StubURLProtocol.requestCount(forPath: "/auth/refresh") == 1)
        #expect(StubURLProtocol.requestCount(forPath: "/groups") == 2)
    }

    // MARK: - Refresh failure

    @Test func refreshFailureClearsTokensAndSignalsLogout() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        let spy = LogoutSpy()
        await client.setAuthenticationLostHandler { await spy.record() }

        StubURLProtocol.respond { _ in Response(statusCode: 401) }   // request and refresh both 401

        await #expect(throws: APIError.unauthorized) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }

        #expect(store.load() == nil)
        #expect(await spy.callCount == 1)
    }

    @Test func aClientWithNoTokensFailsWithoutHittingTheNetworkTwice() async throws {
        let store = InMemoryTokenStore()   // signed out
        let client = makeClient(store: store)
        let spy = LogoutSpy()
        await client.setAuthenticationLostHandler { await spy.record() }

        StubURLProtocol.respond { _ in Response(statusCode: 401) }

        await #expect(throws: APIError.unauthorized) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }
        // The request went out unauthenticated, but there was no refresh token
        // to spend, so no refresh call was made.
        #expect(StubURLProtocol.requestCount(forPath: "/auth/refresh") == 0)
        #expect(await spy.callCount == 1)
    }

    // MARK: - Proactive refresh

    @Test func tokenInsideTheExpiryWindowIsRefreshedBeforeTheRequest() async throws {
        // 60s of life left, well inside the 5-minute window.
        let store = InMemoryTokenStore(tokens: Tokens(jwt: TestJWT.token(expiringIn: 60), refreshToken: "old"))
        let client = makeClient(store: store)
        let newJWT = TestJWT.token(expiringIn: 3600, label: "rotated")

        StubURLProtocol.respond { request in
            request.url?.path == "/auth/refresh"
                ? .json(#"{"jwt":"\#(newJWT)","refreshToken":"new"}"#)
                : .json(Self.groupJSON)
        }

        let _: [GroupSummary] = try await client.request(.listGroups)

        // Refresh happened *first* — the group request never went out stale.
        #expect(StubURLProtocol.recordedRequests.map(\.path) == ["/auth/refresh", "/groups"])
        #expect(StubURLProtocol.recordedRequests.last?.authorizationHeader == "Bearer \(newJWT)")
    }

    @Test func tokenWithPlentyOfLifeIsNotRefreshed() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .json(Self.groupJSON) }

        let _: [GroupSummary] = try await client.request(.listGroups)

        #expect(StubURLProtocol.recordedRequests.map(\.path) == ["/groups"])
    }

    @Test func anUnparseableTokenIsLeftToTheServerToReject() async throws {
        // No `exp` to read → no proactive refresh; the 401 path still covers it.
        let store = InMemoryTokenStore(tokens: Tokens(jwt: "not-a-jwt", refreshToken: "r"))
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .json(Self.groupJSON) }

        let _: [GroupSummary] = try await client.request(.listGroups)

        #expect(StubURLProtocol.recordedRequests.map(\.path) == ["/groups"])
    }

    @Test func concurrentRequestsShareASingleRefresh() async throws {
        // Refresh tokens are single-use and rotate; two in-flight refreshes would
        // replay one and trip the API's family invalidation (Property 5).
        let store = InMemoryTokenStore(tokens: Tokens(jwt: TestJWT.token(expiringIn: 60), refreshToken: "old"))
        let client = makeClient(store: store)

        StubURLProtocol.respond { request in
            request.url?.path == "/auth/refresh"
                // Held open long enough that the second request certainly reaches
                // its own refresh decision while this one is still in flight.
                ? .json(#"{"jwt":"\#(TestJWT.token(expiringIn: 3600))","refreshToken":"new"}"#, delay: 0.3)
                : .json(Self.groupJSON)
        }

        async let first: [GroupSummary] = client.request(.listGroups)
        async let second: [GroupSummary] = client.request(.listGroups)
        _ = try await (first, second)

        #expect(StubURLProtocol.requestCount(forPath: "/auth/refresh") == 1)
        #expect(StubURLProtocol.requestCount(forPath: "/groups") == 2)
    }

    // MARK: - Error mapping

    @Test(arguments: [
        (400, APIError.validationFailed),
        (403, APIError.forbidden),
        (404, APIError.notFound),
        (409, APIError.conflict),
        (422, APIError.validationFailed),
        (500, APIError.serverError),
        (503, APIError.serverError)
    ])
    func httpStatusesMapToTypedErrors(statusCode: Int, expected: APIError) async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in Response(statusCode: statusCode) }

        await #expect(throws: expected) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }
    }

    @Test func transportFailureMapsToNetworkUnavailable() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .transportFailure() }

        await #expect(throws: APIError.networkUnavailable) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }
    }

    @Test func anUndecodableSuccessBodyIsAServerError() async throws {
        let store = InMemoryTokenStore(tokens: freshTokens())
        let client = makeClient(store: store)
        StubURLProtocol.respond { _ in .json(#"{"unexpected":true}"#) }

        await #expect(throws: APIError.serverError) {
            let _: [GroupSummary] = try await client.request(.listGroups)
        }
    }

    // MARK: - Uploads

    @Test func uploadSendsAMultipartBodyWithTheJWT() async throws {
        let tokens = freshTokens()
        let store = InMemoryTokenStore(tokens: tokens)
        let client = makeClient(store: store)
        let id = UUID().uuidString
        StubURLProtocol.respond { _ in
            .json("""
            {"id":"\(id)","userId":"\(id)","groupId":"\(id)","photoUrl":"https://s3/p.jpg",
             "note":"Cracking pint","drinkType":"stout","location":null,"loggedAt":"2026-08-01T18:00:00Z"}
            """)
        }

        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "note", value: "Cracking pint")
        form.addFile(name: "photo", filename: "pint.jpg", mimeType: "image/jpeg", data: Data([0xFF, 0xD8, 0xFF]))

        let _: PintLog = try await client.upload(.createPint, form: form)

        let sent = try #require(StubURLProtocol.recordedRequests.first)
        #expect(sent.request.httpMethod == "POST")
        #expect(sent.request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=test-boundary")
        #expect(sent.authorizationHeader == "Bearer \(tokens.jwt)")
        #expect(sent.bodyString.contains("Cracking pint"))
        #expect(sent.bodyString.contains(#"filename="pint.jpg""#))
    }
}

/// Shorthand so the stub's responses read cleanly above.
private typealias Response = StubURLProtocol.Response
