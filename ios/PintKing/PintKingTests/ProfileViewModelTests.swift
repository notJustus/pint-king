//
//  ProfileViewModelTests.swift
//  PintKingTests
//
//  Task 15: Profile tab root. The user card's logic — load the signed-in user's
//  profile, count their pints across all groups, decide whether to show an
//  initials placeholder — lives in ProfileViewModel, so these tests drive it
//  directly (no View). The profile comes from UserRepository; the total count
//  from PintRepository's "all groups" fetch (groupId: nil).
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct ProfileViewModelTests {

    private func make(
        user: User = MockData.currentUser,
        pints: [PintLog] = MockData.pints
    ) -> ProfileViewModel {
        ProfileViewModel(
            userRepository: MockUserRepository(user: user),
            pintRepository: MockPintRepository(pints: pints, currentUserId: user.id)
        )
    }

    // MARK: - Loading the profile

    @Test func loadPopulatesUserFromRepository() async {
        let vm = make()
        #expect(vm.displayName.isEmpty)   // nothing loaded yet
        await vm.load()
        #expect(vm.displayName == MockData.currentUser.displayName)
    }

    // MARK: - Total pint count

    @Test func totalPintCountReflectsAllGroups() async {
        let vm = make()
        await vm.load()
        // The current user's pints across every group (My Pints "All Groups").
        let expected = MockData.pints.filter { $0.userId == MockData.currentUser.id }.count
        #expect(vm.totalPintCount == expected)
    }

    @Test func totalPintCountIsZeroWithNoPints() async {
        let vm = make(pints: [])
        await vm.load()
        #expect(vm.totalPintCount == 0)
    }

    // MARK: - Avatar placeholder

    @Test func showsInitialsPlaceholderWhenAvatarUrlIsNil() async {
        let noAvatar = User(
            id: MockData.currentUser.id, appleId: "a", displayName: "Dave Smith",
            avatarUrl: nil, activeGroupId: nil
        )
        let vm = make(user: noAvatar)
        await vm.load()
        #expect(vm.showsInitialsPlaceholder)
        #expect(vm.initials == "DS")
    }

    @Test func hidesInitialsPlaceholderWhenAvatarUrlPresent() async {
        let withAvatar = User(
            id: MockData.currentUser.id, appleId: "a", displayName: "Dave Smith",
            avatarUrl: "avatars/x.jpg", activeGroupId: nil
        )
        let vm = make(user: withAvatar)
        await vm.load()
        #expect(vm.showsInitialsPlaceholder == false)
    }
}
