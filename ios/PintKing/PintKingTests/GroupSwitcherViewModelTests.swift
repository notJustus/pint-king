//
//  GroupSwitcherViewModelTests.swift
//  PintKingTests
//
//  Task 8: group switcher. The switcher's logic — load the user's groups, show
//  the active group's name, switch to another — lives in GroupSwitcherViewModel,
//  so these tests drive it directly (no View). The Active_Group is shared state
//  on the repository, so "switching" is asserted by reading it back through the
//  repository, not off the view model.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct GroupSwitcherViewModelTests {

    private func withGroups() -> (GroupSwitcherViewModel, MockGroupRepository) {
        let repo = MockGroupRepository()
        return (GroupSwitcherViewModel(groupRepository: repo), repo)
    }

    private func withoutGroups() -> (GroupSwitcherViewModel, MockGroupRepository) {
        let repo = MockGroupRepository(groups: [], activeGroupId: nil)
        return (GroupSwitcherViewModel(groupRepository: repo), repo)
    }

    // MARK: - Loading + active group name

    @Test func loadPopulatesGroups() async {
        let (vm, _) = withGroups()
        #expect(vm.hasGroups == false)   // nothing fetched yet
        await vm.load()
        #expect(vm.hasGroups == true)
        #expect(vm.groups.count == MockData.groups.count)
    }

    @Test func activeGroupNameDisplayedCorrectly() async {
        let (vm, _) = withGroups()
        await vm.load()
        // The seeded active group is Dave's Friday Club.
        #expect(vm.activeGroupName == MockData.friday.name)
    }

    // MARK: - Switching

    @Test func selectingGroupUpdatesRepository() async {
        let (vm, repo) = withGroups()
        await vm.load()
        #expect(repo.activeGroup?.id == MockData.friday.id)

        await vm.select(MockData.office)

        // Shared state changed on the repository, and the VM reads it back live.
        #expect(repo.activeGroup?.id == MockData.office.id)
        #expect(vm.activeGroupName == MockData.office.name)
    }

    @Test func selectingActiveGroupIsANoOp() async {
        let (vm, repo) = withGroups()
        await vm.load()
        await vm.select(MockData.friday)   // already active
        #expect(repo.activeGroup?.id == MockData.friday.id)
    }

    // MARK: - Empty state

    @Test func emptyStateWhenNoGroups() async {
        let (vm, _) = withoutGroups()
        await vm.load()
        #expect(vm.hasGroups == false)
        #expect(vm.activeGroupName == nil)
    }
}
