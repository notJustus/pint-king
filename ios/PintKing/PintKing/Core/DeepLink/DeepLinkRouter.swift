//
//  DeepLinkRouter.swift
//  PintKing
//
//  The app-lifetime destination for tapped invite links (Task 28,
//  l3-ios-app.md §"Deep-Linking"). `PintKingApp` owns one and feeds it every URL
//  from `.onOpenURL`; it parses the code out and publishes it as
//  `pendingInviteCode`, which the tab bar turns into a Join Confirmation sheet.
//
//  It knows nothing about authentication, on purpose. The design calls for
//  "if signed out, hold the code until after login", but the app already has
//  exactly one place that decides what a signed-out user may see — RootView's
//  three-way gate (ADR-0083) — and the router cannot see all of it anyway
//  (the Profile Setup step is view-local `@State`). So RootView threads this
//  object into the signed-in-and-set-up branch *only*, and the deferral falls
//  out of the gate that already exists: while Login or Profile Setup is on
//  screen there is no sheet modifier to fire, and the moment `isAuthenticated`
//  flips, the branch that presents it renders with the code still pending.
//  Same "shared state drives the UI" move as ADR-0096/0098/0099.
//
//  Holding the code in memory (not the Keychain or UserDefaults) matches the
//  design's "persist invite code locally": an invite the user never got round to
//  accepting should not resurface days later after a cold launch.
//

import Foundation

@MainActor
@Observable
final class DeepLinkRouter {
    /// The invite code from the most recent invite link, waiting to be shown.
    /// Non-nil presents the Join Confirmation sheet over the tab bar.
    ///
    /// Write-restricted so the only ways in are `handle(_:)` (which cannot store
    /// a malformed code) and `consume()`.
    private(set) var pendingInviteCode: String?

    /// `pendingInviteCode` is seedable for previews and tests.
    init(pendingInviteCode: String? = nil) {
        self.pendingInviteCode = pendingInviteCode
    }

    /// Take a URL the system handed the app.
    ///
    /// A URL that is not an invite link is ignored *silently and completely* —
    /// it does not clear a code that is already pending. `.onOpenURL` is a
    /// firehose (Universal Links, and later any custom scheme), so "not mine"
    /// must never be destructive.
    func handle(_ url: URL) {
        guard let code = InviteLink.code(from: url) else { return }
        pendingInviteCode = code
    }

    /// The pending invite has been dealt with — joined, cancelled, or the sheet
    /// dismissed by a swipe. Clearing is what stops it re-presenting: the sheet
    /// is bound to this value, so it must be released by whatever closes it.
    func consume() {
        pendingInviteCode = nil
    }
}
