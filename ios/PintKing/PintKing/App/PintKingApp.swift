//
//  PintKingApp.swift
//  PintKing
//
//  Created by Justus Philips on 12/07/2026.
//

import SwiftUI

@main
struct PintKingApp: App {
    // The session repositories. Mock until backend integration (Task 26).
    // RootView observes `authRepository.isAuthenticated` to gate Login vs Profile
    // Setup vs the tab bar; ContentView reads the group repository's active group
    // to decide whether "+" is enabled. Profile Setup saves through the user
    // repository and requests location via CLLocationPermission (the real
    // CoreLocation-backed requester).
    @State private var authRepository = MockAuthRepository()
    @State private var groupRepository = MockGroupRepository()
    @State private var userRepository = MockUserRepository()
    @State private var leaderboardRepository = MockLeaderboardRepository()
    @State private var pintRepository = MockPintRepository()
    @State private var mapRepository = MockMapRepository()
    @State private var locationPermission = CLLocationPermission()

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: authRepository,
                groupRepository: groupRepository,
                userRepository: userRepository,
                leaderboardRepository: leaderboardRepository,
                pintRepository: pintRepository,
                mapRepository: mapRepository,
                locationPermission: locationPermission
            )
        }
    }
}
