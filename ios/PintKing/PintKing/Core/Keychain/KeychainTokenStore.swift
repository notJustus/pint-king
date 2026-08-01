//
//  KeychainTokenStore.swift
//  PintKing
//
//  The Keychain implementation of the seam NetworkClient reads tokens through
//  (ADR-0104). `InMemoryTokenStore` stays, but only as a test double now.
//
//  This is where the two error contracts meet: `KeychainService` throws, because
//  a wrapper over the Security framework should not pretend a failure did not
//  happen, while `TokenStoring` does not, because a storage failure is
//  indistinguishable *to the client* from "not signed in" — and that already has
//  a defined path (401 → refresh → logout). The swallowing happens here, once,
//  deliberately, rather than being absent from the layer that knows what failed.
//

import Foundation

final class KeychainTokenStore: TokenStoring {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    /// Both halves or nothing: a lone JWT is unusable once it expires, and a
    /// lone refresh token is not a session. Either way the answer is "signed
    /// out", so a half-pair reads as nil.
    func load() -> Tokens? {
        // `try?` flattens the throwing-and-optional read: a thrown error and a
        // missing item arrive as the same nil, which is the point.
        guard let jwtData = try? keychain.load(key: .jwt),
              let refreshData = try? keychain.load(key: .refreshToken),
              let jwt = String(data: jwtData, encoding: .utf8),
              let refreshToken = String(data: refreshData, encoding: .utf8) else {
            return nil
        }
        return Tokens(jwt: jwt, refreshToken: refreshToken)
    }

    /// The pair is written as two items, so a failure on the second would leave
    /// the new JWT beside the *old* refresh token — and replaying an already-spent
    /// refresh token invalidates the whole family server-side (l3-api.md
    /// Property 5). Clearing on a partial write turns that into a plain logout.
    func save(_ tokens: Tokens) {
        do {
            try keychain.save(key: .jwt, data: Data(tokens.jwt.utf8))
            try keychain.save(key: .refreshToken, data: Data(tokens.refreshToken.utf8))
        } catch {
            clear()
        }
    }

    func clear() {
        try? keychain.deleteAll()
    }
}
