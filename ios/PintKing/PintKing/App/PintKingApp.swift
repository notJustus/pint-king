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
    // RootView observes `authRepository.isAuthenticated` to gate Login vs the
    // tab bar; ContentView reads the group repository's active group to decide
    // whether "+" is enabled.
    @State private var authRepository = MockAuthRepository()
    @State private var groupRepository = MockGroupRepository()

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: authRepository,
                groupRepository: groupRepository
            )
        }
    }
}
