//
//  JoinGroupViewModelTests.swift
//  PintKingTests
//
//  Task 21: the code-entry half of the join flow. JoinGroupViewModel does no
//  networking — it normalises what is typed into the invite-code alphabet
//  (8 alphanumerics, Property 10) and gates the hand-off to the confirmation
//  screen — so these tests drive it directly with no repository at all.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct JoinGroupViewModelTests {

    // MARK: - Code normalisation

    @Test func casingIsPreserved() {
        // The API generates codes from a mixed-case alphabet and matches them
        // exactly, so normalising case here would 404 nearly every real code.
        let vm = JoinGroupViewModel()
        vm.inviteCode = "aB3dE6fH"
        #expect(vm.inviteCode == "aB3dE6fH")
    }

    @Test func nonAlphanumericCharactersAreStripped() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = "JO-IN 12!34"
        #expect(vm.inviteCode == "JOIN1234")
    }

    @Test func nonASCIILettersAreStripped() {
        // "é" is a letter to Swift but not to the server's alphabet.
        let vm = JoinGroupViewModel()
        vm.inviteCode = "JOéIN1234"
        #expect(vm.inviteCode == "JOIN1234")
    }

    @Test func codeIsCappedAtEightCharacters() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = "JOIN1234EXTRA"
        #expect(vm.inviteCode == "JOIN1234")
    }

    // MARK: - Validation

    @Test func shortCodeIsInvalid() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = "JOIN12"
        #expect(vm.isCodeValid == false)
    }

    @Test func emptyCodeIsInvalid() {
        let vm = JoinGroupViewModel()
        #expect(vm.isCodeValid == false)
    }

    @Test func eightCharacterCodeIsValid() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = MockData.joinableInviteCode
        #expect(vm.isCodeValid)
    }

    // MARK: - Continuing to the confirmation

    @Test func validCodeShowsConfirmation() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = MockData.joinableInviteCode
        vm.submit()
        #expect(vm.confirmingCode == MockData.joinableInviteCode)
    }

    @Test func invalidCodeDoesNotShowConfirmation() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = "JOIN"
        vm.submit()
        #expect(vm.confirmingCode == nil)
    }

    @Test func cancellingConfirmationReturnsToEditing() {
        let vm = JoinGroupViewModel()
        vm.inviteCode = MockData.joinableInviteCode
        vm.submit()
        vm.cancelConfirmation()

        #expect(vm.confirmingCode == nil)
        // The code survives the pop so it can be corrected rather than retyped.
        #expect(vm.inviteCode == MockData.joinableInviteCode)
    }
}
