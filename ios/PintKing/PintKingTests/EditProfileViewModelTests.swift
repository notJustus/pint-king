//
//  EditProfileViewModelTests.swift
//  PintKingTests
//
//  Task 16: Edit Profile. The screen's logic lives in EditProfileViewModel — it
//  pre-fills the current display name, validates edits (1–30 chars), optionally
//  validates a newly chosen avatar (5 MB cap), and on Save writes only what
//  changed through the UserRepository. These tests drive that logic directly (no
//  View) against a MockUserRepository.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct EditProfileViewModelTests {

    private func makeViewModel(
        user: User = MockData.currentUser,
        repository: MockUserRepository? = nil
    ) -> (EditProfileViewModel, MockUserRepository) {
        let repo = repository ?? MockUserRepository(user: user)
        let vm = EditProfileViewModel(user: user, userRepository: repo)
        return (vm, repo)
    }

    // MARK: - Pre-fill

    @Test func nameIsPrefilledFromTheCurrentUser() {
        let (vm, _) = makeViewModel()
        #expect(vm.displayName == MockData.currentUser.displayName)
    }

    // MARK: - Display name validation

    @Test func emptyNameIsInvalid() {
        let (vm, _) = makeViewModel()
        vm.displayName = ""
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func whitespaceOnlyNameIsInvalid() {
        let (vm, _) = makeViewModel()
        vm.displayName = "   "
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func nameOverThirtyCharsIsInvalid() {
        let (vm, _) = makeViewModel()
        vm.displayName = String(repeating: "a", count: 31)
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func nameWithinRangeIsValid() {
        let (vm, _) = makeViewModel()
        vm.displayName = "D"
        #expect(vm.isDisplayNameValid)
        vm.displayName = String(repeating: "a", count: 30)
        #expect(vm.isDisplayNameValid)
    }

    // MARK: - Change tracking

    @Test func noChangesWhenNothingEdited() {
        let (vm, _) = makeViewModel()
        #expect(vm.hasChanges == false)
    }

    @Test func editingNameRegistersAsAChange() {
        let (vm, _) = makeViewModel()
        vm.displayName = "New Name"
        #expect(vm.hasChanges)
    }

    @Test func reEnteringTheOriginalNameIsNotAChange() {
        let (vm, _) = makeViewModel()
        vm.displayName = "  Dave Smith  "   // same after trimming
        #expect(vm.hasChanges == false)
    }

    @Test func selectingAnAvatarRegistersAsAChange() {
        let (vm, _) = makeViewModel()
        vm.selectAvatar(Data([0xFF, 0xD8, 0xFF, 0x00]))
        #expect(vm.hasChanges)
    }

    // MARK: - Avatar validation

    @Test func validJpegAvatarIsAccepted() {
        let (vm, _) = makeViewModel()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])
        vm.selectAvatar(jpeg)
        #expect(vm.avatarData == jpeg)
        #expect(vm.errorMessage == nil)
    }

    @Test func oversizeAvatarIsRejected() {
        let (vm, _) = makeViewModel()
        var big = Data([0xFF, 0xD8, 0xFF])
        big.append(Data(count: 5 * 1024 * 1024 + 1))
        vm.selectAvatar(big)
        #expect(vm.avatarData == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test func unsupportedAvatarTypeIsRejected() {
        let (vm, _) = makeViewModel()
        vm.selectAvatar(Data([0x00, 0x01, 0x02, 0x03]))
        #expect(vm.avatarData == nil)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Save

    @Test func saveWritesTheTrimmedNameToTheRepository() async {
        let user = User(
            id: MockData.daveId, appleId: "x", displayName: "Dave Smith",
            avatarUrl: nil, activeGroupId: nil
        )
        let (vm, repo) = makeViewModel(user: user)
        vm.displayName = "  New Name  "
        await vm.save()
        let saved = try? await repo.getProfile()
        #expect(saved?.displayName == "New Name")
        #expect(vm.isSaved)
        #expect(vm.errorMessage == nil)
        #expect(vm.isSaving == false)
    }

    @Test func saveUploadsAValidatedAvatar() async {
        let user = User(
            id: MockData.daveId, appleId: "x", displayName: "Dave Smith",
            avatarUrl: nil, activeGroupId: nil
        )
        let (vm, repo) = makeViewModel(user: user)
        vm.selectAvatar(Data([0xFF, 0xD8, 0xFF, 0x00]))
        await vm.save()
        let saved = try? await repo.getProfile()
        #expect(saved?.avatarUrl != nil)
        #expect(vm.isSaved)
    }

    @Test func saveDoesNotRenameWhenOnlyTheAvatarChanged() async {
        // Give the repo a distinct starting name; if save() renames needlessly,
        // this would still pass — so instead we assert the name is untouched by
        // checking it equals the original after an avatar-only save.
        let user = User(
            id: MockData.daveId, appleId: "x", displayName: "Dave Smith",
            avatarUrl: nil, activeGroupId: nil
        )
        let (vm, repo) = makeViewModel(user: user)
        vm.selectAvatar(Data([0xFF, 0xD8, 0xFF, 0x00]))
        await vm.save()
        let saved = try? await repo.getProfile()
        #expect(saved?.displayName == "Dave Smith")
        #expect(saved?.avatarUrl != nil)
    }

    @Test func saveWithInvalidNameShowsErrorAndDoesNotComplete() async {
        let (vm, _) = makeViewModel()
        vm.displayName = ""
        await vm.save()
        #expect(vm.isSaved == false)
        #expect(vm.errorMessage != nil)
    }

    @Test func saveWithNoChangesStillCompletes() async {
        // Saving without edits is a harmless no-op that dismisses the screen.
        let (vm, _) = makeViewModel()
        await vm.save()
        #expect(vm.isSaved)
        #expect(vm.errorMessage == nil)
    }
}
