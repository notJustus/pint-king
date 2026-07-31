//
//  CreateGroupViewModelTests.swift
//  PintKingTests
//
//  Task 20: Create Group screen. The screen's logic — validate the group name
//  (1–50 chars), create it through the GroupRepository (which sets it active),
//  and surface the 99-group-limit error — lives in CreateGroupViewModel, so these
//  tests drive it directly (no View) against a MockGroupRepository.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct CreateGroupViewModelTests {

    private func make(
        repository: MockGroupRepository? = nil
    ) -> (CreateGroupViewModel, MockGroupRepository) {
        let repo = repository ?? MockGroupRepository()
        let vm = CreateGroupViewModel(groupRepository: repo)
        return (vm, repo)
    }

    // MARK: - Name validation

    @Test func emptyNameIsInvalid() {
        let (vm, _) = make()
        vm.name = ""
        #expect(vm.isNameValid == false)
    }

    @Test func whitespaceOnlyNameIsInvalid() {
        let (vm, _) = make()
        vm.name = "   "
        #expect(vm.isNameValid == false)
    }

    @Test func nameOverFiftyCharsIsInvalid() {
        let (vm, _) = make()
        vm.name = String(repeating: "a", count: 51)
        #expect(vm.isNameValid == false)
    }

    @Test func nameWithinRangeIsValid() {
        let (vm, _) = make()
        vm.name = "A"
        #expect(vm.isNameValid)
        vm.name = String(repeating: "a", count: 50)
        #expect(vm.isNameValid)
    }

    // MARK: - Successful creation

    @Test func createAddsGroupAndSetsItActive() async {
        let (vm, repo) = make()
        vm.name = "New Crew"
        await vm.create()

        #expect(vm.isCreated)
        #expect(vm.errorMessage == nil)
        // createGroup sets the new group active (mock + real API).
        #expect(repo.activeGroup?.name == "New Crew")
    }

    @Test func createTrimsWhitespaceFromName() async {
        let (vm, repo) = make()
        vm.name = "  Padded  "
        await vm.create()
        #expect(repo.activeGroup?.name == "Padded")
    }

    @Test func createWithInvalidNameDoesNotCallRepository() async {
        let (vm, repo) = make()
        let before = repo.activeGroup
        vm.name = ""
        await vm.create()

        #expect(vm.isCreated == false)
        #expect(vm.errorMessage != nil)
        // Active group unchanged — no create happened.
        #expect(repo.activeGroup?.id == before?.id)
    }

    // MARK: - Error path

    @Test func limitReachedSurfacesErrorAndDoesNotComplete() async {
        let repo = MockGroupRepository()
        repo.shouldFailCreate = true
        let (vm, _) = make(repository: repo)
        vm.name = "Doomed"
        await vm.create()

        #expect(vm.isCreated == false)
        #expect(vm.errorMessage != nil)
    }

    @Test func isCreatingIsFalseAfterCompletion() async {
        let (vm, _) = make()
        vm.name = "New Crew"
        await vm.create()
        #expect(vm.isCreating == false)
    }
}
