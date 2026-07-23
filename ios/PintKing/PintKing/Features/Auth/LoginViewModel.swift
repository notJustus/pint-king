//
//  LoginViewModel.swift
//  PintKing
//
//  Screen-local state for the Login screen. Holds the loading flag and the
//  human-readable error message; delegates the actual sign-in to the injected
//  AuthRepository. Auth state (isAuthenticated, currentUser) lives on the
//  repository, not here — the root view observes the repository to swap Login
//  for the tab bar, so this view model never needs to expose it.
//

import Foundation

@MainActor
@Observable
final class LoginViewModel {
    /// True while a sign-in attempt is in flight; the button shows a spinner
    /// and is disabled so a second tap can't fire a concurrent login.
    private(set) var isLoggingIn = false

    /// A human-readable message shown inline when a sign-in attempt fails, or
    /// nil when there's nothing to show. Cleared at the start of every attempt.
    private(set) var errorMessage: String?

    private let authRepository: any AuthRepositoryProtocol

    init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    /// Run the (mock) Sign in with Apple flow. Clears any prior error, shows the
    /// loading state, and on failure maps the thrown error to a message the
    /// Login screen renders with a Retry button. On success the repository flips
    /// `isAuthenticated`, which the root view observes to navigate away.
    func login() async {
        errorMessage = nil
        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            try await authRepository.login()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Retry after a failure. Identical to `login()` (which already clears the
    /// error first); named separately so the view reads clearly.
    func retry() async {
        await login()
    }

    /// Map a thrown error to a human-readable line. Sign in with Apple failures
    /// surface as APIError once the real flow lands (Task 26); until then the
    /// mock throws `.serverError`. Anything unrecognised falls back to a generic
    /// message rather than leaking a raw error description.
    private static func message(for error: Error) -> String {
        switch error {
        case APIError.networkUnavailable:
            return "You appear to be offline. Check your connection and try again."
        default:
            return "Sign in failed. Please try again."
        }
    }
}
