//
//  DeepLinkRouterTests.swift
//  PintKingTests
//
//  Task 28: the app-lifetime holder for tapped invite links. The router has no
//  dependencies at all — parsing lives in InviteLink and the decision about
//  *when* a pending code may be shown lives in RootView's gate (ADR-0106) — so
//  these tests drive it directly.
//
//  The auth-state half of the requirement is covered by
//  `pendingCodeSurvivesSigningIn`: the router deliberately does not branch on
//  authentication, so what has to hold is that a code parsed while signed out is
//  still there once the session flips. That the signed-in branch is the only one
//  that presents it is structural (RootView threads the router into ContentView
//  alone) and is exercised in the Task 30 UI pass.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct DeepLinkRouterTests {

    // MARK: - Parsing into pending state

    @Test func validInviteLinkBecomesAPendingCode() {
        let router = DeepLinkRouter()
        router.handle(InviteLink.url(for: "aB3dE6fH"))
        #expect(router.pendingInviteCode == "aB3dE6fH")
    }

    @Test func unrelatedURLIsIgnored() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://example.com/join/aB3dE6fH")!)
        #expect(router.pendingInviteCode == nil)
    }

    @Test func unrelatedURLDoesNotClearAPendingCode() {
        // `.onOpenURL` sees every URL the app is handed, so "not an invite link"
        // must be inert rather than destructive.
        let router = DeepLinkRouter()
        router.handle(InviteLink.url(for: "aB3dE6fH"))
        router.handle(URL(string: "https://pintking.app/about")!)
        #expect(router.pendingInviteCode == "aB3dE6fH")
    }

    @Test func aSecondInviteLinkReplacesTheFirst() {
        let router = DeepLinkRouter()
        router.handle(InviteLink.url(for: "aB3dE6fH"))
        router.handle(InviteLink.url(for: "kM9nP2qR"))
        #expect(router.pendingInviteCode == "kM9nP2qR")
    }

    // MARK: - Lifetime

    @Test func consumingClearsThePendingCode() {
        // Whatever closes the sheet — Join, Cancel or a swipe — calls this; if it
        // did not, the sheet's binding would re-present immediately.
        let router = DeepLinkRouter(pendingInviteCode: "aB3dE6fH")
        router.consume()
        #expect(router.pendingInviteCode == nil)
    }

    @Test func pendingCodeSurvivesSigningIn() async throws {
        // A link tapped while signed out: the router holds the code across the
        // auth transition, so the branch that presents it renders with it still
        // pending. This is the "persist in memory until after login" requirement.
        let auth = MockAuthRepository()
        let router = DeepLinkRouter()

        router.handle(InviteLink.url(for: "aB3dE6fH"))
        #expect(auth.isAuthenticated == false)
        #expect(router.pendingInviteCode == "aB3dE6fH")

        try await auth.login()

        #expect(auth.isAuthenticated)
        #expect(router.pendingInviteCode == "aB3dE6fH")
    }
}
