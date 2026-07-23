//
//  AuthRepositoryProtocol.swift
//  PintKing
//
//  Owns the Sign in with Apple flow and the app's authentication state. The
//  root view (Task 6) switches between Login and the tab bar by observing
//  `isAuthenticated`; `currentUser` is the signed-in profile once login
//  succeeds. Protocols are `@MainActor` because the conforming repositories are
//  `@Observable` classes whose state SwiftUI reads on the main actor.
//

import Foundation

@MainActor
protocol AuthRepositoryProtocol: AnyObject {
    /// True once a session exists. Root navigation keys off this.
    var isAuthenticated: Bool { get }

    /// The signed-in user, or nil when unauthenticated.
    var currentUser: User? { get }

    /// Perform Sign in with Apple. On success sets `isAuthenticated` and
    /// populates `currentUser`; on failure throws (Login shows the error).
    func login() async throws

    /// Clear the session: drops `currentUser` and sets `isAuthenticated = false`.
    func logout() async throws
}
