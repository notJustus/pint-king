//
//  JoinConfirmationViewModelTests.swift
//  PintKingTests
//
//  Task 21: the confirming half of the join flow. Every join outcome lands here,
//  because the API resolves an invite code only by attempting the join
//  (Property 11) — so these tests drive JoinConfirmationViewModel against a
//  MockGroupRepository whose codes reproduce all three failures:
//
//    - an unknown code                       → 404 notFound
//    - a code of a group already joined      → 409 conflict
//    - MockData.blockedInviteCode            → 403 forbidden
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct JoinConfirmationViewModelTests {

    private func make(
        code: String,
        repository: MockGroupRepository? = nil
    ) -> (JoinConfirmationViewModel, MockGroupRepository) {
        let repo = repository ?? MockGroupRepository()
        let vm = JoinConfirmationViewModel(inviteCode: code, groupRepository: repo)
        return (vm, repo)
    }

    // MARK: - Successful join

    @Test func confirmJoinsGroupAndSetsItActive() async {
        let (vm, repo) = make(code: MockData.joinableInviteCode)
        await vm.join()

        #expect(vm.joinedGroup?.name == MockData.joinableGroup.name)
        #expect(vm.errorMessage == nil)
        // joinGroup sets the joined group active (mock + real API), which is what
        // navigates Home to its leaderboard.
        #expect(repo.activeGroup?.name == MockData.joinableGroup.name)
    }

    @Test func joinedGroupAppearsInTheGroupList() async throws {
        let (vm, repo) = make(code: MockData.joinableInviteCode)
        await vm.join()

        let groups = try await repo.getGroups()
        #expect(groups.contains { $0.name == MockData.joinableGroup.name })
    }

    @Test func isJoiningIsFalseAfterCompletion() async {
        let (vm, _) = make(code: MockData.joinableInviteCode)
        await vm.join()
        #expect(vm.isJoining == false)
    }

    // MARK: - Error paths (Property 11)

    @Test func unknownCodeShowsGroupNotFound() async {
        let (vm, repo) = make(code: "NOSUCH12")
        let activeBefore = repo.activeGroup
        await vm.join()

        #expect(vm.joinedGroup == nil)
        #expect(vm.errorMessage == "Group not found. Check the invite code and try again.")
        #expect(repo.activeGroup?.id == activeBefore?.id)
    }

    @Test func codeOfAGroupAlreadyJoinedShowsAlreadyAMember() async {
        // Sunday League is one of the current user's groups, so its code is a 409.
        let (vm, _) = make(code: MockData.sunday.inviteCode)
        await vm.join()

        #expect(vm.joinedGroup == nil)
        #expect(vm.errorMessage == "You're already a member of this group.")
    }

    @Test func blockedCodeShowsRemovedFromGroup() async {
        let (vm, _) = make(code: MockData.blockedInviteCode)
        await vm.join()

        #expect(vm.joinedGroup == nil)
        #expect(vm.errorMessage == "You have been removed from this group and can't rejoin.")
    }

    @Test func joiningTwiceFromTheSameScreenSurfacesTheConflict() async {
        let (vm, _) = make(code: MockData.joinableInviteCode)
        await vm.join()
        #expect(vm.errorMessage == nil)

        // The first join made us a member, so a second tap is a 409 — each attempt
        // re-evaluates against current state rather than reusing the last result.
        await vm.join()
        #expect(vm.errorMessage == "You're already a member of this group.")
    }
}
