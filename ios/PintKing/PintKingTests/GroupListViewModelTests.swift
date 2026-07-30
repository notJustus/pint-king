//
//  GroupListViewModelTests.swift
//  PintKingTests
//
//  Task 19: Group List screen. The screen's logic — load every group the user
//  belongs to, expose the per-group admin role + member count, and surface an
//  empty state — lives in GroupListViewModel, so these tests drive it directly
//  (no View). Groups arrive as `GroupSummary` (the GET /groups shape) carrying
//  the caller's `role` and `memberCount`; the mock derives both from its seeded
//  member lists.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct GroupListViewModelTests {

    private func withGroups() -> (GroupListViewModel, MockGroupRepository) {
        let repo = MockGroupRepository()
        return (GroupListViewModel(groupRepository: repo), repo)
    }

    private func withoutGroups() -> (GroupListViewModel, MockGroupRepository) {
        let repo = MockGroupRepository(groups: [], activeGroupId: nil)
        return (GroupListViewModel(groupRepository: repo), repo)
    }

    // MARK: - Loading

    @Test func loadPopulatesGroups() async {
        let (vm, _) = withGroups()
        #expect(vm.hasGroups == false)   // nothing fetched yet
        await vm.load()
        #expect(vm.hasGroups == true)
        #expect(vm.groups.count == MockData.groups.count)
        #expect(vm.isLoading == false)
    }

    @Test func loadCarriesMemberCounts() async {
        let (vm, _) = withGroups()
        await vm.load()
        // Friday Club is seeded with 4 members.
        let friday = vm.groups.first { $0.id == MockData.fridayId }
        #expect(friday?.memberCount == 4)
    }

    // MARK: - Admin badge (role)

    @Test func adminRoleReportedForGroupsUserAdmins() async {
        let (vm, _) = withGroups()
        await vm.load()
        // Dave is admin of Friday Club, a plain member of Sunday League.
        let friday = vm.groups.first { $0.id == MockData.fridayId }
        let sunday = vm.groups.first { $0.id == MockData.sundayId }
        #expect(friday?.role == .admin)
        #expect(sunday?.role == .member)
    }

    // MARK: - Empty state

    @Test func emptyStateWhenNoGroups() async {
        let (vm, _) = withoutGroups()
        await vm.load()
        #expect(vm.hasGroups == false)
        #expect(vm.groups.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Refresh

    @Test func refreshReloadsWithoutBlanking() async {
        let (vm, repo) = withGroups()
        await vm.load()
        #expect(vm.groups.count == MockData.groups.count)

        // A new group appears (e.g. created elsewhere), then refresh picks it up.
        _ = try? await repo.createGroup(name: "New Crew")
        await vm.refresh()
        #expect(vm.groups.count == MockData.groups.count + 1)
        #expect(vm.groups.contains { $0.name == "New Crew" })
    }
}
