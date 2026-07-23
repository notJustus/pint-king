//
//  PintKingApp.swift
//  PintKing
//
//  Created by Justus Philips on 12/07/2026.
//

import SwiftUI

@main
struct PintKingApp: App {
    // The single group repository for the session. Mock until backend
    // integration (Task 26); ContentView reads its active group to decide
    // whether "+" is enabled.
    @State private var groupRepository = MockGroupRepository()

    var body: some Scene {
        WindowGroup {
            ContentView(groupRepository: groupRepository)
        }
    }
}
