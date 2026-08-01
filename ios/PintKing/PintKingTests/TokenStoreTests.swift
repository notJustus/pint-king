//
//  TokenStoreTests.swift
//  PintKingTests
//
//  Task 26: the two pieces the interceptor's proactive refresh rests on — where
//  tokens live, and how long the JWT has left. JWTExpiry deliberately does no
//  verification: an unreadable token yields nil, which the client reads as
//  "don't refresh early", never as "the token is bad".
//

import Foundation
import Testing
@testable import PintKing

struct TokenStoreTests {

    // MARK: - InMemoryTokenStore

    @Test func storeRoundTripsAndClears() {
        let store = InMemoryTokenStore()
        #expect(store.load() == nil)

        store.save(Tokens(jwt: "a", refreshToken: "b"))
        #expect(store.load() == Tokens(jwt: "a", refreshToken: "b"))

        store.save(Tokens(jwt: "c", refreshToken: "d"))
        #expect(store.load()?.jwt == "c")

        store.clear()
        #expect(store.load() == nil)
    }

    @Test func storeCanBeSeededAtInit() {
        let store = InMemoryTokenStore(tokens: Tokens(jwt: "seed", refreshToken: "r"))
        #expect(store.load()?.jwt == "seed")
    }

    // MARK: - JWTExpiry

    @Test func expiryIsReadFromTheExpClaim() throws {
        let expected = Date().addingTimeInterval(900)
        let expiry = try #require(JWTExpiry.expiry(of: TestJWT.token(expiringIn: 900)))

        // `exp` is whole seconds, so allow a second of rounding either way.
        #expect(abs(expiry.timeIntervalSince(expected)) < 1)
    }

    @Test func alreadyExpiredTokensReportAPastDate() throws {
        let expiry = try #require(JWTExpiry.expiry(of: TestJWT.token(expiringIn: -60)))
        #expect(expiry < Date())
    }

    @Test(arguments: [
        "",                 // empty
        "not-a-jwt",        // no segments
        "header.payload",   // two segments
        "a.b.c"             // three segments, but the payload isn't base64
    ])
    func malformedTokensHaveNoExpiry(token: String) {
        #expect(JWTExpiry.expiry(of: token) == nil)
    }

    @Test func aTokenWithoutAnExpClaimHasNoExpiry() {
        // Payload is `{"sub":"x"}`, base64url-encoded and unpadded.
        #expect(JWTExpiry.expiry(of: "header.eyJzdWIiOiJ4In0.signature") == nil)
    }
}
