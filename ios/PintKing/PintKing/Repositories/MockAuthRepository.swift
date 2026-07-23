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
}
