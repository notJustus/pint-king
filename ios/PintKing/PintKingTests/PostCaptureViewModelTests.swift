//
//  PostCaptureViewModelTests.swift
//  PintKingTests
//
//  Task 13: post-capture bottom sheet logic. The view model owns the optional
//  metadata (note capped at 280, toggleable drink type) and the Done hand-off to
//  PintRepository.createPint — a photo-only pint is valid, so both fields may be
//  empty. Driven against the real MockGroupRepository/MockPintRepository so we can
//  assert what gets logged.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct PostCaptureViewModelTests {

    private let photo = Data([0xFF, 0xD8, 0xFF])   // JPEG magic bytes, stand-in

    private func make(
        group: MockGroupRepository? = nil,
        pint: MockPintRepository? = nil,
        location: MockLocationProvider? = nil
    ) -> (PostCaptureViewModel, MockGroupRepository, MockPintRepository) {
        let group = group ?? MockGroupRepository()
        let pint = pint ?? MockPintRepository()
        let location = location ?? MockLocationProvider()
        let vm = PostCaptureViewModel(
            photoData: photo, groupRepository: group, pintRepository: pint,
            locationProvider: location
        )
        return (vm, group, pint)
    }

    // MARK: - Note field

    @Test func noteEnforces280CharLimit() {
        let (vm, _, _) = make()
        vm.note = String(repeating: "a", count: 300)
        #expect(vm.note.count == 280)
        #expect(vm.remainingCharacters == 0)
    }

    @Test func noteUnderLimitIsKeptVerbatim() {
        let (vm, _, _) = make()
        vm.note = "First pint of the night"
        #expect(vm.note == "First pint of the night")
        #expect(vm.remainingCharacters == 280 - 23)
    }

    // MARK: - Drink type

    @Test func selectDrinkTypeSetsIt() {
        let (vm, _, _) = make()
        vm.selectDrinkType(.stout)
        #expect(vm.drinkType == .stout)
    }

    @Test func reselectingSameDrinkTypeClearsIt() {
        let (vm, _, _) = make()
        vm.selectDrinkType(.stout)
        vm.selectDrinkType(.stout)
        #expect(vm.drinkType == nil)
    }

    @Test func selectingDifferentDrinkTypeReplacesIt() {
        let (vm, _, _) = make()
        vm.selectDrinkType(.stout)
        vm.selectDrinkType(.lager)
        #expect(vm.drinkType == .lager)
    }

    // MARK: - Save

    @Test func doneWithNoMetadataStillLogsPhotoOnlyPint() async {
        let (vm, group, pint) = make()
        await vm.save()

        #expect(vm.isSaved)
        let logged = try? await pint.getMyPints(groupId: group.activeGroup?.id)
        let newest = logged?.first
        #expect(newest?.note == nil)
        #expect(newest?.drinkType == nil)
    }

    @Test func doneWithMetadataPassesNoteAndDrinkType() async {
        let (vm, group, pint) = make()
        vm.note = "  Guinness, obviously  "
        vm.selectDrinkType(.stout)
        await vm.save()

        #expect(vm.isSaved)
        let newest = try? await pint.getMyPints(groupId: group.activeGroup?.id).first
        #expect(newest?.note == "Guinness, obviously")   // trimmed
        #expect(newest?.drinkType == .stout)
    }

    @Test func blankNoteIsSavedAsNil() async {
        let (vm, _, pint) = make()
        vm.note = "    "
        await vm.save()

        let newest = try? await pint.getMyPints(groupId: nil).first
        #expect(newest?.note == nil)
    }

    @Test func saveWithNoActiveGroupShowsErrorAndDoesNotLog() async {
        let group = MockGroupRepository(groups: [], activeGroupId: nil)
        let (vm, _, pint) = make(group: group)
        let before = (try? await pint.getMyPints(groupId: nil))?.count ?? 0
        await vm.save()

        #expect(!vm.isSaved)
        #expect(vm.errorMessage != nil)
        // Nothing new logged for the current user across all groups.
        let after = (try? await pint.getMyPints(groupId: nil))?.count ?? 0
        #expect(after == before)
    }

    // MARK: - Location (Task 14)

    @Test func locationReceivedIsAttachedToPint() async {
        let coordinate = Coordinate(latitude: 51.5, longitude: -0.12)
        let location = MockLocationProvider(location: coordinate)
        let (vm, group, pint) = make(location: location)
        await vm.save()

        #expect(vm.isSaved)
        #expect(location.requestCount == 1)
        let newest = try? await pint.getMyPints(groupId: group.activeGroup?.id).first
        #expect(newest?.location == coordinate)
    }

    @Test func locationTimeoutLogsPintWithoutLocationAndNoError() async {
        // nil stands in for the 10s timeout the real service maps to no location.
        let location = MockLocationProvider(location: nil)
        let (vm, group, pint) = make(location: location)
        await vm.save()

        #expect(vm.isSaved)
        #expect(vm.errorMessage == nil)
        let newest = try? await pint.getMyPints(groupId: group.activeGroup?.id).first
        #expect(newest?.location == nil)
    }

    @Test func locationDeniedLogsPintWithoutLocationAndNoError() async {
        // A denied permission also surfaces as nil from the provider.
        let location = MockLocationProvider(location: nil)
        let (vm, group, pint) = make(location: location)
        await vm.save()

        #expect(vm.isSaved)
        #expect(vm.errorMessage == nil)
        let newest = try? await pint.getMyPints(groupId: group.activeGroup?.id).first
        #expect(newest?.location == nil)
    }

    @Test func locationFetchIsStartedOnlyOnce() async {
        let location = MockLocationProvider(location: Coordinate(latitude: 1, longitude: 2))
        let (vm, _, _) = make(location: location)
        vm.startLocationFetch()
        vm.startLocationFetch()
        await vm.save()   // also calls startLocationFetch defensively

        #expect(location.requestCount == 1)
    }
}
