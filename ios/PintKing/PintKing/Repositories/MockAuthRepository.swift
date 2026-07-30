//
//  MockAuthRepository.swift
//  PintKing
//
//  In-memory auth for UI development. `login()` flips `isAuthenticated` and sets
//  the mock current user; `shouldFailLogin` lets a caller (or a test) force the
//  error path so the Login screen's retry can be exercised without a backend.
//

import Foundation

@MainActor
@Observable
final class MockAuthRepository: AuthRepositoryProtocol {
    private(set) var isAuthenticated: Bool
    private(set) var currentUser: User?

    /// When true, the next `login()` throws instead of succeeding.
    var shouldFailLogin = false

    /// When true, the next `deleteAccount()` throws instead of succeeding, so the
    /// Settings screen's error path can be exercised without a backend.
    var shouldFailDelete = false

    /// Start signed out by default; pass `authenticated: true` to skip Login in
    /// previews/tests that want to land straight on the tab bar.
    init(authenticated: Bool = false) {
        self.isAuthenticated = authenticated
        self.currentUser = authenticated ? MockData.currentUser : nil
    }

    func login() async throws {
        if shouldFailLogin {
            throw APIError.serverError
        }
        currentUser = MockData.currentUser
        isAuthenticated = true
    }

    func logout() async throws {
        currentUser = nil
        isAuthenticated = false
    }

    func deleteAccount() async throws {
        if shouldFailDelete {
            throw APIError.serverError
        }
        // Same local effect as logout — clear the session so RootView returns to
        // Login. The real repo also performs the server cascade + Keychain wipe.
        currentUser = nil
        isAuthenticated = false
    }
}
