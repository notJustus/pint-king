//
//  RootView.swift
//  PintKing
//
//  The top-level gate. Observes the AuthRepository and routes between three
//  states: signed out → Login; signed in but setup not yet finished →
//  Profile Setup; signed in and set up → the tab bar. Because the repository is
//  `@Observable`, flipping `isAuthenticated` (login succeeds, or logout/delete
//  account later) re-renders this view and swaps the whole screen — no manual
//  navigation call needed. The one-shot setup step is tracked locally with
//  `didCompleteSetup`, flipped by ProfileSetupView's completion callback.
//

import SwiftUI

struct RootView: View {
    /// `any AuthRepositoryProtocol` is stored so previews/tests can inject a
    /// mock; the concrete type is `@Observable`, so reading `isAuthenticated`
    /// here subscribes this view to its changes.
    private let authRepository: any AuthRepositoryProtocol
    private let groupRepository: any GroupRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol
    private let leaderboardRepository: any LeaderboardRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol
    private let mapRepository: any MapRepositoryProtocol
    private let locationPermission: any LocationPermissionRequesting
    private let deepLinkRouter: DeepLinkRouter

    /// Whether the first-login Profile Setup step is done for this session. The
    /// setup screen is shown after auth until this flips true.
    @State private var didCompleteSetup = false

    init(
        authRepository: any AuthRepositoryProtocol,
        groupRepository: any GroupRepositoryProtocol,
        userRepository: any UserRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        mapRepository: any MapRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting,
        deepLinkRouter: DeepLinkRouter
    ) {
        self.authRepository = authRepository
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.leaderboardRepository = leaderboardRepository
        self.pintRepository = pintRepository
        self.mapRepository = mapRepository
        self.locationPermission = locationPermission
        self.deepLinkRouter = deepLinkRouter
    }

    var body: some View {
        if !authRepository.isAuthenticated {
            LoginView(authRepository: authRepository)
        } else if !didCompleteSetup {
            ProfileSetupView(
                initialDisplayName: authRepository.currentUser?.displayName ?? "",
                userRepository: userRepository,
                locationPermission: locationPermission,
                onComplete: { didCompleteSetup = true }
            )
        } else {
            // The deep-link router is handed to this branch *only*. That is the
            // whole implementation of "hold an invite link until after login":
            // while the two branches above are on screen nothing is subscribed
            // to `pendingInviteCode`, so a code parsed during sign-in simply
            // waits, and this branch presents it the moment it renders
            // (ADR-0106).
            ContentView(
                groupRepository: groupRepository,
                userRepository: userRepository,
                leaderboardRepository: leaderboardRepository,
                pintRepository: pintRepository,
                mapRepository: mapRepository,
                authRepository: authRepository,
                locationPermission: locationPermission,
                deepLinkRouter: deepLinkRouter
            )
        }
    }
}

#Preview("Signed out") {
    RootView(
        authRepository: MockAuthRepository(),
        groupRepository: MockGroupRepository(),
        userRepository: MockUserRepository(),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository(),
        mapRepository: MockMapRepository(),
        locationPermission: MockLocationPermission(),
        deepLinkRouter: DeepLinkRouter()
    )
}

#Preview("Signed in") {
    RootView(
        authRepository: MockAuthRepository(authenticated: true),
        groupRepository: MockGroupRepository(),
        userRepository: MockUserRepository(),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository(),
        mapRepository: MockMapRepository(),
        locationPermission: MockLocationPermission(),
        deepLinkRouter: DeepLinkRouter()
    )
}
