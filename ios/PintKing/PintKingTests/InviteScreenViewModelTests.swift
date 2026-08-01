//
//  InviteScreenViewModelTests.swift
//  PintKingTests
//
//  Task 23: the Invite screen. The screen's whole job is to keep three displays
//  (code, link, QR) in agreement and to rotate them together, so these tests
//  drive InviteScreenViewModel directly — no View.
//
//  The load-bearing invariant is that the link and the QR are *derived* from the
//  code: every regeneration test asserts all three moved, not just the code.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct InviteScreenViewModelTests {

    /// The repository is passed in rather than defaulted: a `@MainActor` type
    /// cannot be constructed in a default argument (those are evaluated
    /// nonisolated).
    private func makeViewModel(
        inviteCode: String = "aB3dE6fH",
        isAdmin: Bool = true,
        repository: MockGroupRepository
    ) -> (InviteScreenViewModel, MockGroupRepository) {
        let vm = InviteScreenViewModel(
            groupId: MockData.fridayId,
            groupName: "Friday Club",
            inviteCode: inviteCode,
            isAdmin: isAdmin,
            groupRepository: repository
        )
        return (vm, repository)
    }

    // MARK: - Derived displays

    @Test func inviteLinkIsDerivedFromTheCode() {
        let (vm, _) = makeViewModel(repository: MockGroupRepository())
        #expect(vm.inviteLinkText == "https://pintking.app/join/aB3dE6fH")
    }

    @Test func qrCodeIsGeneratedFromTheInviteLink() {
        let (vm, _) = makeViewModel(repository: MockGroupRepository())
        let qr = try! #require(vm.qrCode)
        // Decoding the rendered image must give back the exact link — the QR is
        // the link, not merely "some image".
        #expect(QRDecoder.decode(qr) == vm.inviteLinkText)
    }

    @Test func shareTextNamesTheGroupAndCarriesTheLink() {
        let (vm, _) = makeViewModel(repository: MockGroupRepository())
        #expect(vm.shareTitle == "Join Friday Club on Pint King")
        #expect(vm.shareMessage.contains("Friday Club"))
        #expect(vm.shareMessage.contains("aB3dE6fH"))
        #expect(vm.inviteLink.absoluteString == vm.inviteLinkText)
    }

    // MARK: - Regenerate

    @Test func regenerateReplacesCodeLinkAndQRTogether() async {
        let repo = MockGroupRepository()
        let (vm, _) = makeViewModel(inviteCode: MockData.friday.inviteCode, repository: repo)
        let oldCode = vm.inviteCode

        await vm.regenerate()

        #expect(vm.inviteCode != oldCode)
        #expect(vm.inviteLinkText == "https://pintking.app/join/\(vm.inviteCode)")

        // The QR followed the code: it decodes to the *new* link.
        let qr = try! #require(vm.qrCode)
        #expect(QRDecoder.decode(qr) == vm.inviteLinkText)

        #expect(vm.isRegenerating == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func regenerateUpdatesTheStoredGroup() async {
        let repo = MockGroupRepository()
        let (vm, _) = makeViewModel(inviteCode: MockData.friday.inviteCode, repository: repo)

        await vm.regenerate()

        // The repository is the source of truth: what the screen shows is what a
        // later fetch of the group returns.
        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.group.inviteCode == vm.inviteCode)
    }

    @Test func regenerateFailureShowsErrorAndKeepsTheOldCode() async {
        let repo = MockGroupRepository()
        repo.shouldFailRegenerate = true
        let (vm, _) = makeViewModel(repository: repo)
        let oldCode = vm.inviteCode
        let oldLink = vm.inviteLinkText

        await vm.regenerate()

        #expect(vm.inviteCode == oldCode)
        #expect(vm.inviteLinkText == oldLink)
        #expect(vm.errorMessage != nil)
        #expect(vm.isRegenerating == false)
    }

    @Test func nonAdminCannotRegenerate() async {
        let repo = MockGroupRepository()
        let (vm, _) = makeViewModel(
            inviteCode: MockData.friday.inviteCode, isAdmin: false, repository: repo
        )

        await vm.regenerate()

        #expect(vm.inviteCode == MockData.friday.inviteCode)
        #expect(vm.errorMessage != nil)
        // The guard is in the model, not just the missing button: the repository
        // was never asked to rotate anything.
        let detail = try! await repo.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.group.inviteCode == MockData.friday.inviteCode)
    }

    @Test func regenerateWarningExplainsTheOldCodeStopsWorking() {
        // The copy the confirmation dialog shows before the destructive action
        // (l3-ios-app.md §"Regenerate Invite Code").
        #expect(InviteScreenViewModel.regenerateWarning.contains("invalidate"))
        #expect(InviteScreenViewModel.regenerateWarning.contains("old code"))
    }
}
