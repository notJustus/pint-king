//
//  ProjectSetupTests.swift
//  PintKingTests
//
//  Task 1: confirms the project builds, the app module is importable via
//  @testable, and the Swift Testing target runs. This is the foundation
//  smoke test — later tasks add real behaviour tests alongside it.
//

import Testing
@testable import PintKing

struct ProjectSetupTests {

    @Test func testTargetRuns() {
        // A trivially-true assertion: if this passes, the Swift Testing
        // runner is wired up and the PintKing module compiled and linked.
        #expect(Bool(true))
    }

    @Test func appModuleIsImportable() {
        // Referencing a symbol from the app target proves @testable import
        // resolves the module (i.e. the app builds and is testable).
        _ = PintKingApp.self
    }
}
