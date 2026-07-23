//
//  RootTabViewModelTests.swift
//  PintKingTests
//
//  Task 5: tab bar skeleton. All the branching lives in RootTabViewModel — the
//  "+" tab is a trigger, not a destination, and is a no-op when there's no
//  active group. These tests drive that logic directly (no View), so tab
//  selection, modal presentation, and the disabled state are all covered
//  without touching SwiftUI or the simulator UI.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct RootTabViewModelTests {

    /// A view model whose group repository has an active group (so "+" is enabled).
    private func withActiveGroup() -> RootTabViewModel {
        RootTabViewModel(groupRepository: MockGroupRepository())
    }

    /// A view model whose group repository has no groups (so "+" is disabled).
    private func withoutActiveGroup() -> RootTabViewModel {
        RootTabViewModel(groupRepository: MockGroupRepository(groups: [], activeGroupId: nil))
    }

    // MARK: - Tab selection

    @Test func startsOnHome() {
        let vm = withActiveGroup()
        #expect(vm.selectedTab == .home)
        #expect(vm.isCameraPresented == false)
    }

    @Test func selectingProfileSwitchesTab() {
        let vm = withActiveGroup()
        vm.select(.profile)
        #expect(vm.selectedTab == .profile)
        #expect(vm.isCameraPresented == false)
    }

    @Test func selectingHomeFromProfileSwitchesBack() {
        let vm = withActiveGroup()
        vm.select(.profile)
        vm.select(.home)
        #expect(vm.selectedTab == .home)
    }

    // MARK: - "+" presents the camera (and is not a real tab)

    @Test func selectingAddPresentsCameraAndLeavesTabUnchanged() {
        let vm = withActiveGroup()
        vm.select(.profile)          // start on some real tab
        vm.select(.add)
        #expect(vm.isCameraPresented == true)
        // The visible tab must not change — "add" is a trigger, not a destination.
        #expect(vm.selectedTab == .profile)
    }

    @Test func dismissingCameraReturnsToPreviousTab() {
        let vm = withActiveGroup()
        vm.select(.add)
        vm.isCameraPresented = false  // the modal's close button drives this
        #expect(vm.selectedTab == .home)
    }

    // MARK: - Disabled state (no active group)

    @Test func canLogPintReflectsActiveGroup() {
        #expect(withActiveGroup().canLogPint == true)
        #expect(withoutActiveGroup().canLogPint == false)
    }

    @Test func selectingAddWithoutActiveGroupDoesNothing() {
        let vm = withoutActiveGroup()
        vm.select(.add)
        #expect(vm.isCameraPresented == false)
        #expect(vm.selectedTab == .home)
    }
}
