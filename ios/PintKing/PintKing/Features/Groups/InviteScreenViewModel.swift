//
//  InviteScreenViewModel.swift
//  PintKing
//
//  Screen-local state for the Invite screen (Group Detail → Invite Members,
//  Task 23; requirements §5.4 and §5.10, l3-ios-app.md §"Regenerate Invite Code").
//  The screen shows one group's invite code, the link derived from it, and a QR
//  code of that link — and lets an admin rotate the code.
//
//  Two things shape this view model:
//
//  1. **The code is the only state; the link and the QR are consequences of it.**
//     `inviteLink` is a pure function of `inviteCode` (InviteLink), and the QR is
//     a rendering of that link. So regeneration updates exactly one property and
//     all three displays follow — there is no way for the screen to show a code
//     and a QR that disagree. The QR bitmap is cached rather than computed on
//     every read, because rendering it is CoreImage work and SwiftUI reads
//     properties on every body evaluation.
//
//  2. **It trusts what Group Detail already loaded instead of re-fetching.** The
//     code and `isAdmin` arrive as immutable inputs from the screen that just
//     fetched them (GroupDetailViewModel derives `isAdmin` from a fresh member
//     list, ADR-0100). Nothing but this screen's own Regenerate button can change
//     the code while it is open, so a second `getGroupDetail` on appear would only
//     re-answer a question that was answered a moment ago. Group Detail refreshes
//     when this screen goes away, so a regeneration propagates back.
//

import Foundation
import UIKit

@MainActor
@Observable
final class InviteScreenViewModel {

    /// The group's name — used in the share message ("Join Friday Club on Pint
    /// King"). An immutable input; this screen never renames anything.
    let groupName: String

    /// Whether the signed-in user may rotate the code (requirements §5.10:
    /// admin only). Derived by Group Detail from the loaded member list and passed
    /// in, so there is one source of truth for role per visit.
    let isAdmin: Bool

    /// The group's current invite code. The screen's only mutable state —
    /// everything else on screen is derived from it.
    private(set) var inviteCode: String

    /// The QR code for the current `inviteLink`, re-rendered whenever the code
    /// changes. Nil only if CoreImage fails.
    private(set) var qrCode: UIImage?

    /// True while a regeneration is in flight; the button shows a spinner.
    private(set) var isRegenerating = false

    /// Human-readable error shown inline, or nil when there's nothing to show.
    private(set) var errorMessage: String?

    private let groupId: UUID
    private let groupRepository: any GroupRepositoryProtocol

    /// The confirmation copy shown before regenerating (l3-ios-app.md
    /// §"Regenerate Invite Code"). Lives here so the warning and the action it
    /// guards stay together; the view owns only whether the dialog is up, exactly
    /// as Group Detail does for its leave and remove prompts.
    static let regenerateWarning = """
        This will invalidate the current code. Anyone with the old code or link \
        won't be able to join.
        """

    init(
        groupId: UUID,
        groupName: String,
        inviteCode: String,
        isAdmin: Bool,
        groupRepository: any GroupRepositoryProtocol
    ) {
        self.groupId = groupId
        self.groupName = groupName
        self.inviteCode = inviteCode
        self.isAdmin = isAdmin
        self.groupRepository = groupRepository
        self.qrCode = QRCodeGenerator.image(for: InviteLink.url(for: inviteCode).absoluteString)
    }

    // MARK: - Derived state

    /// The shareable Universal Link for the current code. The same format the
    /// deep-link handler parses (Task 28) — see `InviteLink`.
    var inviteLink: URL {
        InviteLink.url(for: inviteCode)
    }

    /// The link as displayable text.
    var inviteLinkText: String {
        inviteLink.absoluteString
    }

    /// Subject line for the share sheet (used by Mail and similar).
    var shareTitle: String {
        "Join \(groupName) on Pint King"
    }

    /// Body text accompanying the shared link.
    var shareMessage: String {
        "Join \(groupName) on Pint King — tap the link or enter code \(inviteCode)."
    }

    // MARK: - Actions

    /// Rotate the invite code, invalidating the old one (requirements §5.10,
    /// Property 12). Guarded on `isAdmin` so the rule lives in the model and not
    /// only in whether the view drew a button — the same client-mirrors-server
    /// relationship as `GroupDetailViewModel.leave()` (ADR-0100).
    func regenerate() async {
        guard isAdmin else {
            errorMessage = "Only a group admin can regenerate the invite code."
            return
        }

        errorMessage = nil
        isRegenerating = true
        defer { isRegenerating = false }

        do {
            let updated = try await groupRepository.regenerateInviteCode(groupId: groupId)
            inviteCode = updated.inviteCode
            qrCode = QRCodeGenerator.image(for: inviteLinkText)
        } catch {
            errorMessage = "Couldn't regenerate the invite code. Please try again."
        }
    }
}
