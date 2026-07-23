//
//  ProfileSetupViewModelTests.swift
//  PintKingTests
//
//  Task 7: profile setup. The screen's logic lives in ProfileSetupViewModel —
//  it validates the display name (1–30 chars), optionally validates a chosen
//  avatar, saves both through the UserRepository, requests location permission,
//  and tracks whether setup is complete. These tests drive that logic directly
//  (no View, no simulator) against a MockUserRepository and a MockLocationPermission.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct ProfileSetupViewModelTests {

    private func makeViewModel(
        initialDisplayName: String = "Dave Smith",
        user: (any UserRepositoryProtocol)? = nil,
        location: MockLocationPermission? = nil
    ) -> ProfileSetupViewModel {
        ProfileSetupViewModel(
            initialDisplayName: initialDisplayName,
            userRepository: user ?? MockUserRepository(),
            locationPermission: location ?? MockLocationPermission()
        )
    }

    // MARK: - Display name validation

    @Test func emptyNameIsInvalid() {
        let vm = makeViewModel(initialDisplayName: "")
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func whitespaceOnlyNameIsInvalid() {
        let vm = makeViewModel(initialDisplayName: "   ")
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func nameOverThirtyCharsIsInvalid() {
        let vm = makeViewModel(initialDisplayName: String(repeating: "a", count: 31))
        #expect(vm.isDisplayNameValid == false)
    }

    @Test func nameWithinRangeIsValid() {
        #expect(makeViewModel(initialDisplayName: "D").isDisplayNameValid)
        #expect(makeViewModel(initialDisplayName: "Dave Smith").isDisplayNameValid)
        #expect(makeViewModel(initialDisplayName: String(repeating: "a", count: 30)).isDisplayNameValid)
    }

    @Test func nameIsPrefilledFromTheCurrentUser() {
        let vm = makeViewModel(initialDisplayName: "Dave Smith")
        #expect(vm.displayName == "Dave Smith")
    }

    // MARK: - Completion tracking

    @Test func setupStartsIncomplete() {
        let vm = makeViewModel()
        #expect(vm.isComplete == false)
    }

    @Test func continueWithValidNameCompletesSetup() async {
        let vm = makeViewModel(initialDisplayName: "Dave Smith")
        await vm.continueSetup()
        #expect(vm.isComplete)
        #expect(vm.errorMessage == nil)
        #expect(vm.isSaving == false)
    }

    @Test func continueWithInvalidNameDoesNotComplete() async {
        let vm = makeViewModel(initialDisplayName: "")
        await vm.continueSetup()
        #expect(vm.isComplete == false)
        #expect(vm.errorMessage != nil)
    }

    @Test func continueSavesTheTrimmedNameToTheRepository() async {
        let user = MockUserRepository()
        let vm = makeViewModel(initialDisplayName: "  New Name  ", user: user)
        await vm.continueSetup()
        let saved = try? await user.getProfile()
        #expect(saved?.displayName == "New Name")
    }

    // MARK: - Location permission

    @Test func continueStoresGrantedLocationDecision() async {
        let location = MockLocationPermission(decision: .granted)
        let vm = makeViewModel(location: location)
        await vm.continueSetup()
        #expect(location.requestCount == 1)
        #expect(vm.locationPermissionGranted == true)
        #expect(vm.isComplete)
    }

    @Test func continueStoresDeniedLocationDecisionButStillCompletes() async {
        let location = MockLocationPermission(decision: .denied)
        let vm = makeViewModel(location: location)
        await vm.continueSetup()
        #expect(vm.locationPermissionGranted == false)
        // Location is optional — a denial must not block finishing setup.
        #expect(vm.isComplete)
    }

    @Test func locationIsNotRequestedWhenNameIsInvalid() async {
        let location = MockLocationPermission()
        let vm = makeViewModel(initialDisplayName: "", location: location)
        await vm.continueSetup()
        #expect(location.requestCount == 0)
        #expect(vm.locationPermissionGranted == nil)
    }

    // MARK: - Avatar validation

    @Test func validJpegAvatarIsAccepted() {
        let vm = makeViewModel()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])
        vm.selectAvatar(jpeg)
        #expect(vm.avatarData == jpeg)
        #expect(vm.errorMessage == nil)
    }

    @Test func oversizeAvatarIsRejected() {
        let vm = makeViewModel()
        // 5 MB + 1 byte, JPEG magic bytes at the front.
        var big = Data([0xFF, 0xD8, 0xFF])
        big.append(Data(count: 5 * 1024 * 1024 + 1))
        vm.selectAvatar(big)
        #expect(vm.avatarData == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test func unsupportedAvatarTypeIsRejected() {
        let vm = makeViewModel()
        let notAnImage = Data([0x00, 0x01, 0x02, 0x03])
        vm.selectAvatar(notAnImage)
        #expect(vm.avatarData == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test func continueUploadsAValidatedAvatar() async {
        let user = MockUserRepository(user: User(
            id: MockData.daveId, appleId: "x", displayName: "Dave Smith",
            avatarUrl: nil, activeGroupId: nil
        ))
        let vm = makeViewModel(user: user)
        vm.selectAvatar(Data([0xFF, 0xD8, 0xFF, 0x00]))
        await vm.continueSetup()
        let saved = try? await user.getProfile()
        #expect(saved?.avatarUrl != nil)
    }
}
