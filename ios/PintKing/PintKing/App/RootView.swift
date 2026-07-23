//
//  RootView.swift
//  PintKing
//
//  The top-level gate. Observes the AuthRepository and shows the Login screen
//  when signed out, the tab bar when signed in. Because the repository is
//  `@Observable`, flipping `isAuthenticated` (login succeeds, or logout/delete
//  account later) re-renders this view and swaps the whole screen — no manual
//  navigation call needed.
//

import SwiftUI

struct RootView: View {
    /// `any AuthRepositoryProtocol` is stored so previews/tests can inject a
    /// mock; the concrete type is `@Observable`, so reading `isAuthenticated`
    /// here subscribes this view to its changes.
    private let authRepository: any AuthRepositoryProtocol
    private let groupRepository: any GroupRepositoryProtocol

    init(
        authRepository: any AuthRepositoryProtocol,
        groupRepository: any GroupRepositoryProtocol
    ) {
        self.authRepository = authRepository
        self.groupRepository = groupRepository
    }

    var body: some View {
        if authRepository.isAuthenticated {
            ContentView(groupRepository: groupRepository)
        } else {
            LoginView(authRepository: authRepository)
        }
    }
}

#Preview("Signed out") {
    RootView(
        authRepository: MockAuthRepository(),
        groupRepository: MockGroupRepository()
    )
}

#Preview("Signed in") {
    RootView(
        authRepository: MockAuthRepository(authenticated: true),
        groupRepository: MockGroupRepository()
    )
}
