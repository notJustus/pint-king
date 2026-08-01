//
//  GroupDetailViewModelTests.swift
//  PintKingTests
//
//  Task 22: Group Detail screen. Every decision the screen makes — who may run
//  admin actions, what leaving would do, whether a rename is allowed — lives in
//  GroupDetailViewModel, so these tests drive it directly (no View).
//
//  The three leave outcomes are all reachable from the shared fixtures:
//   - sole admin WITH members  → Friday Club (Dave is its only admin, 4 members)
//   - not sole admin           → Sunday League (Dave is a plain member)
//   - sole admin, NO members   → a group created through the mock (the creator is
//                                its admin and its only member)
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct GroupDetailViewModelTests {

    private func summary(
        _ group: Group, role: GroupMemberRole, memberCount: Int
    ) -> GroupSummary {
        GroupSummary(
            id: group.id, name: group.name, inviteCode: group.inviteCode,
            role: role, memberCount: memberCount
        )
    }

    /// Friday Club: Dave is the sole admin, three other members.
    private func adminOfGroupWithMembers() -> (GroupDetailViewModel, MockGroupRepository) {
        let repo = MockGroupRepository()
        let vm = GroupDetailViewModel(
            group: summary(MockData.friday, role: .admin, memberCount: 4),
            groupRepository: repo,
            userRepository: MockUserRepository()
        )
        return (vm, repo)
    }

    /// Sunday League: Dave is a plain member, Emma is the admin.
    private func plainMember() -> (GroupDetailViewModel, MockGroupRepository) {
        let repo = MockGroupRepository()
        let vm = GroupDetailViewModel(
            group: summary(MockData.sunday, role: .member, memberCount: 4),
            groupRepository: repo,
            userRepository: MockUserRepository()
        )
        return (vm, repo)
    }

    /// A freshly created group: the creator is its admin and its only member.
    private func soleMemberAdmin() async -> (GroupDetailViewModel, MockGroupRepository) {
        let repo = MockGroupRepository()
        let group = try! await repo.createGroup(name: "Just Me")
        let vm = GroupDetailViewModel(
            group: summary(group, role: .admin, memberCount: 1),
            groupRepository: repo,
            userRepository: MockUserRepository()
        )
        return (vm, repo)
    }

    // MARK: - Loading

    @Test func loadPopulatesMembersAndName() async {
        let (vm, _) = adminOfGroupWithMembers()
        #expect(vm.members.isEmpty)
        await vm.load()
        #expect(vm.members.count == 4)
        #expect(vm.groupName == "Friday Club")
        #expect(vm.isLoading == false)
    }

    // MARK: - Admin gating

    @Test func adminActionsVisibleForAdmin() async {
        let (vm, _) = adminOfGroupWithMembers()
        await vm.load()
        #expect(vm.isAdmin)

        // Every other member is manageable; the admin themselves is not.
        let emma = vm.members.first { $0.userId == MockData.emmaId }!
        let dave = vm.members.first { $0.userId == MockData.daveId }!
        #expect(vm.canManage(emma))
        #expect(vm.canPromote(emma))
        #expect(vm.canManage(dave) == false)
        #expect(vm.canPromote(dave) == false)
    }

    @Test func adminActionsHiddenForPlainMember() async {
        let (vm, _) = plainMember()
        await vm.load()
        #expect(vm.isAdmin == false)
        for member in vm.members {
            #expect(vm.canManage(member) == false)
            #expect(vm.canPromote(member) == false)
        }
    }

    @Test func alreadyAdminMemberCannotBePromoted() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()
        try? await repo.promoteMember(groupId: MockData.fridayId, userId: MockData.emmaId)
        await vm.refresh()

        let emma = vm.members.first { $0.userId == MockData.emmaId }!
        #expect(emma.role == .admin)
        #expect(vm.canManage(emma))          // can still be removed
        #expect(vm.canPromote(emma) == false) // but not promoted again
    }

    // MARK: - Remove member

    @Test func removeMemberCallsRepositoryAndDropsRow() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()

        await vm.removeMember(userId: MockData.oliviaId)

        #expect(vm.members.count == 3)
        #expect(vm.members.contains { $0.userId == MockData.oliviaId } == false)
        #expect(vm.errorMessage == nil)

        // The repository is the source of truth, not just the VM's local copy.
        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.members.contains { $0.userId == MockData.oliviaId } == false)
    }

    // MARK: - Promote member

    @Test func promoteMemberCallsRepositoryAndUpdatesRole() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()

        await vm.promoteMember(userId: MockData.liamId)

        #expect(vm.members.first { $0.userId == MockData.liamId }?.role == .admin)
        #expect(vm.errorMessage == nil)

        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.members.first { $0.userId == MockData.liamId }?.role == .admin)
    }

    // MARK: - Rename

    @Test func renameWithValidNameCallsRepository() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()

        vm.beginRename()
        #expect(vm.nameDraft == "Friday Club")   // seeded from the current name
        vm.nameDraft = "  Thursday Club  "       // trimmed before saving
        #expect(vm.isNameDraftValid)
        await vm.rename()

        #expect(vm.groupName == "Thursday Club")
        #expect(vm.errorMessage == nil)

        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.group.name == "Thursday Club")
    }

    @Test func renameRejectsEmptyName() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()

        vm.beginRename()
        vm.nameDraft = "   "
        #expect(vm.isNameDraftValid == false)
        await vm.rename()

        #expect(vm.errorMessage != nil)
        #expect(vm.groupName == "Friday Club")
        // Aborted before any repository call.
        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.group.name == "Friday Club")
    }

    @Test func renameRejectsNameOver50Characters() async {
        let (vm, _) = adminOfGroupWithMembers()
        await vm.load()

        vm.beginRename()
        vm.nameDraft = String(repeating: "a", count: 51)
        #expect(vm.isNameDraftValid == false)
        await vm.rename()

        #expect(vm.errorMessage != nil)
        #expect(vm.groupName == "Friday Club")

        // Exactly 50 is fine.
        vm.nameDraft = String(repeating: "a", count: 50)
        #expect(vm.isNameDraftValid)
    }

    // MARK: - Leave outcomes

    @Test func soleAdminWithMembersMustPromoteFirst() async {
        let (vm, repo) = adminOfGroupWithMembers()
        await vm.load()

        #expect(vm.leaveOutcome == .promoteFirst)

        // And the leave is refused outright — no repository call.
        await vm.leave()
        #expect(vm.didLeave == false)
        #expect(vm.errorMessage != nil)
        #expect(try! await repo.getGroups().contains { $0.id == MockData.fridayId })
    }

    @Test func soleAdminWithNoOtherMembersLeaveDeletesGroup() async {
        let (vm, repo) = await soleMemberAdmin()
        await vm.load()

        #expect(vm.members.count == 1)
        #expect(vm.leaveOutcome == .deletesGroup)

        await vm.leave()
        #expect(vm.didLeave)
        #expect(vm.errorMessage == nil)
        #expect(try! await repo.getGroups().contains { $0.name == "Just Me" } == false)
    }

    @Test func nonSoleAdminLeavesNormally() async {
        let (vm, repo) = plainMember()
        await vm.load()

        #expect(vm.leaveOutcome == .simple)

        await vm.leave()
        #expect(vm.didLeave)
        #expect(vm.errorMessage == nil)
        #expect(try! await repo.getGroups().contains { $0.id == MockData.sundayId } == false)
    }

    @Test func promotingAnotherMemberUnblocksLeaving() async {
        let (vm, _) = adminOfGroupWithMembers()
        await vm.load()
        #expect(vm.leaveOutcome == .promoteFirst)

        // A second admin exists, so the sole-admin rule no longer applies.
        await vm.promoteMember(userId: MockData.emmaId)
        #expect(vm.leaveOutcome == .simple)

        await vm.leave()
        #expect(vm.didLeave)
    }
}
