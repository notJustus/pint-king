//
//  TokenStore.swift
//  PintKing
//
//  Where the session's tokens live, as seen by the networking layer.
//
//  NetworkClient needs the JWT on every request and the refresh token when one
//  expires — but AuthRepository (which owns the *user-visible* session) will be
//  built on top of NetworkClient, so the client cannot depend on it without a
//  cycle. This protocol is the seam: the client reads and writes tokens, and
//  whoever owns storage decides where they actually sit. `KeychainTokenStore`
//  (Task 27) is the real one; the in-memory store below is now a test double.
//

import Foundation

/// The token pair issued by `/auth/apple` and rotated by `/auth/refresh`.
struct Tokens: Equatable, Sendable {
    let jwt: String
    let refreshToken: String
}

/// Reads/writes are deliberately non-throwing: a storage failure is
/// indistinguishable, to the client, from "not signed in" — and that already
/// has a well-defined path (401 → refresh → logout).
protocol TokenStoring: AnyObject, Sendable {
    func load() -> Tokens?
    func save(_ tokens: Tokens)
    func clear()
}

/// Process-lifetime token storage — a test double, for suites that want a store
/// they can seed and inspect without touching the system keychain.
final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: Tokens?

    init(tokens: Tokens? = nil) {
        self.tokens = tokens
    }

    func load() -> Tokens? {
        lock.withLock { tokens }
    }

    func save(_ tokens: Tokens) {
        lock.withLock { self.tokens = tokens }
    }

    func clear() {
        lock.withLock { tokens = nil }
    }
}

/// Reads the `exp` claim out of a JWT without verifying it.
///
/// The client only needs the expiry to decide whether to refresh *early* — the
/// server is the authority on validity, so no signature check happens (or could
/// happen) here. An unparseable token yields nil, which simply means "don't
/// refresh proactively"; the reactive 401 path still covers it.
enum JWTExpiry {

    static func expiry(of jwt: String) -> Date? {
        let segments = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let payload = base64URLDecode(String(segments[1])),
              let claims = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = claims["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    /// JWT segments are base64url (RFC 4648 §5) and unpadded — translate the two
    /// substituted characters back and re-pad before handing it to Foundation.
    private static func base64URLDecode(_ segment: String) -> Data? {
        var base64 = segment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
