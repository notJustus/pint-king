//
//  KeychainService.swift
//  PintKing
//
//  A thin wrapper over the Security framework's four C calls, so the rest of the
//  app never assembles a CFDictionary or reads an OSStatus.
//
//  Scope matters here: every item is written with the same `service` attribute,
//  which makes that string the app's private partition of the keychain. It is
//  what lets `deleteAll()` be a single delete of "everything we own" rather than
//  a loop over known keys — retired keys from an older build get cleaned up too —
//  and it is what lets tests use their own partition without touching the app's.
//

import Foundation
import Security

/// The items the app stores. An enum rather than free-form strings: the set is
/// small, closed, and a typo in a key is a silent "not signed in".
enum KeychainKey: String, CaseIterable, Sendable {
    case jwt
    case refreshToken
}

/// Anything the Security framework reports that isn't success or "not found".
/// The raw status is carried because there is nothing useful to say about it
/// beyond what the OS said.
enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

struct KeychainService: Sendable {

    /// The `kSecAttrService` every item is filed under — this instance's
    /// partition of the keychain.
    private let service: String

    init(service: String = "com.pintking.tokens") {
        self.service = service
    }

    // MARK: - Operations

    /// Writes `data` at `key`, replacing any existing value.
    ///
    /// `SecItemAdd` fails with `errSecDuplicateItem` on a second write, so the
    /// delete-then-add makes this an upsert. Callers only ever want the latest
    /// token pair; there is no case where the previous value should win.
    func save(key: KeychainKey, data: Data) throws {
        try? delete(key: key)

        var attributes = query(for: key)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = accessibility

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Returns the stored value, or nil if nothing is stored at `key`.
    ///
    /// "Absent" is a normal outcome (a signed-out app), so `errSecItemNotFound`
    /// is nil rather than an error; anything else genuinely went wrong and is
    /// thrown, because a read failure and an empty keychain are not the same
    /// fact at this level.
    func load(key: KeychainKey) throws -> Data? {
        var query = query(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes the item at `key`. Deleting something that isn't there succeeds —
    /// the caller asked for it to be gone, and it is.
    func delete(key: KeychainKey) throws {
        let status = SecItemDelete(query(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes every item in this service's partition — a query with no `account`
    /// matches all of them, so this is one call, not a loop over `KeychainKey`.
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Query construction

    private func query(for key: KeychainKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }

    /// `AfterFirstUnlock`, not `WhenUnlocked`: a queued pint upload can run in the
    /// background while the device is locked, and it needs the JWT to do it.
    /// `ThisDeviceOnly` keeps the pair out of iCloud Keychain and encrypted
    /// backups, so restoring a backup onto another device does not carry a live
    /// session with it — the user signs in with Apple again, which is cheap.
    private var accessibility: CFString { kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }
}
