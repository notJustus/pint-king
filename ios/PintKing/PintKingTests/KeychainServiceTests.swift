//
//  KeychainServiceTests.swift
//  PintKingTests
//
//  Task 27: the real keychain, not a fake — these exercise the Security
//  framework on the simulator's keychain. Each suite instance writes under its
//  own `service` string (a fresh UUID), which is both how the tests stay
//  isolated from each other under parallel execution and a live demonstration of
//  the partitioning `deleteAll()` relies on.
//

import Foundation
import Testing
@testable import PintKing

final class KeychainServiceTests {

    private let keychain: KeychainService
    private let serviceName = "com.pintking.tests.\(UUID().uuidString)"

    init() {
        keychain = KeychainService(service: serviceName)
    }

    deinit {
        try? KeychainService(service: serviceName).deleteAll()
    }

    // MARK: - Round trip

    @Test func savedDataLoadsBackUnchanged() throws {
        try keychain.save(key: .jwt, data: Data("header.payload.signature".utf8))

        let loaded = try #require(try keychain.load(key: .jwt))
        #expect(String(data: loaded, encoding: .utf8) == "header.payload.signature")
    }

    @Test func savingTwiceReplacesTheValue() throws {
        try keychain.save(key: .jwt, data: Data("first".utf8))
        try keychain.save(key: .jwt, data: Data("second".utf8))

        let loaded = try #require(try keychain.load(key: .jwt))
        #expect(String(data: loaded, encoding: .utf8) == "second")
    }

    @Test func keysAreIndependent() throws {
        try keychain.save(key: .jwt, data: Data("j".utf8))
        try keychain.save(key: .refreshToken, data: Data("r".utf8))

        #expect(try keychain.load(key: .jwt) == Data("j".utf8))
        #expect(try keychain.load(key: .refreshToken) == Data("r".utf8))
    }

    // MARK: - Absence

    @Test func loadingAMissingKeyReturnsNil() throws {
        #expect(try keychain.load(key: .jwt) == nil)
    }

    // MARK: - Delete

    @Test func deleteRemovesTheItem() throws {
        try keychain.save(key: .jwt, data: Data("j".utf8))
        try keychain.delete(key: .jwt)

        #expect(try keychain.load(key: .jwt) == nil)
    }

    @Test func deletingAMissingKeySucceeds() throws {
        // The caller asked for it to be gone, and it is.
        try keychain.delete(key: .refreshToken)
    }

    @Test func deleteLeavesOtherKeysAlone() throws {
        try keychain.save(key: .jwt, data: Data("j".utf8))
        try keychain.save(key: .refreshToken, data: Data("r".utf8))

        try keychain.delete(key: .jwt)

        #expect(try keychain.load(key: .jwt) == nil)
        #expect(try keychain.load(key: .refreshToken) == Data("r".utf8))
    }

    // MARK: - Delete all

    @Test func deleteAllClearsEveryKey() throws {
        for key in KeychainKey.allCases {
            try keychain.save(key: key, data: Data(key.rawValue.utf8))
        }

        try keychain.deleteAll()

        for key in KeychainKey.allCases {
            #expect(try keychain.load(key: key) == nil)
        }
    }

    @Test func deleteAllOnAnEmptyPartitionSucceeds() throws {
        try keychain.deleteAll()
    }

    /// The load-bearing property behind `deleteAll()`: `service` partitions the
    /// keychain, so clearing one instance cannot reach another's items — which is
    /// what makes "delete everything we own" safe to express as one query.
    @Test func deleteAllOnlyClearsItsOwnService() throws {
        let other = KeychainService(service: "com.pintking.tests.\(UUID().uuidString)")
        defer { try? other.deleteAll() }

        try keychain.save(key: .jwt, data: Data("mine".utf8))
        try other.save(key: .jwt, data: Data("theirs".utf8))

        try keychain.deleteAll()

        #expect(try keychain.load(key: .jwt) == nil)
        #expect(try other.load(key: .jwt) == Data("theirs".utf8))
    }
}

// MARK: - KeychainTokenStore

final class KeychainTokenStoreTests {

    private let serviceName = "com.pintking.tests.\(UUID().uuidString)"
    private let keychain: KeychainService
    private let store: KeychainTokenStore

    init() {
        keychain = KeychainService(service: serviceName)
        store = KeychainTokenStore(keychain: keychain)
    }

    deinit {
        try? KeychainService(service: serviceName).deleteAll()
    }

    @Test func tokensSurviveARoundTrip() {
        store.save(Tokens(jwt: "j", refreshToken: "r"))

        #expect(store.load() == Tokens(jwt: "j", refreshToken: "r"))
    }

    @Test func anEmptyKeychainReadsAsSignedOut() {
        #expect(store.load() == nil)
    }

    @Test func savingAgainReplacesThePair() {
        store.save(Tokens(jwt: "j1", refreshToken: "r1"))
        store.save(Tokens(jwt: "j2", refreshToken: "r2"))

        #expect(store.load() == Tokens(jwt: "j2", refreshToken: "r2"))
    }

    @Test func clearRemovesBothHalves() throws {
        store.save(Tokens(jwt: "j", refreshToken: "r"))

        store.clear()

        #expect(store.load() == nil)
        #expect(try keychain.load(key: .jwt) == nil)
        #expect(try keychain.load(key: .refreshToken) == nil)
    }

    /// A JWT with no refresh token beside it is not a session — once it expires
    /// there is no way back, so the store reports signed out rather than handing
    /// the client half a pair.
    @Test func aHalfPairReadsAsSignedOut() throws {
        try keychain.save(key: .jwt, data: Data("orphan".utf8))

        #expect(store.load() == nil)
    }
}
