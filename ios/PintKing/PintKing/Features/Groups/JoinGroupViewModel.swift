//
//  JoinGroupViewModel.swift
//  PintKing
//
//  Screen-local state for the Join Group screen (Task 21, l3-ios-app.md §"Join via
//  Manual Code Entry"): type an 8-character invite code, then continue to the Join
//  Confirmation screen. Groups are invite-only — there is no search or discovery,
//  so this screen is nothing but the code field.
//
//  This half of the flow does no networking at all. It normalises what the user
//  types into the invite-code alphabet (Property 10: exactly 8 alphanumerics) and
//  checks the *format*; whether the code resolves to a joinable group is the
//  server's answer, and it arrives on the confirmation screen.
//

import Foundation

@MainActor
@Observable
final class JoinGroupViewModel {
    /// The invite code, bound to the text field. The setter normalises every
    /// keystroke (and paste) into the code alphabet, so `inviteCode` can never
    /// hold anything the server would reject on format — the same
    /// "the property enforces its own bounds" trick as PostCaptureViewModel's
    /// note cap, which is why the view needs no filtering of its own.
    var inviteCode: String = "" {
        didSet {
            let normalized = Self.normalize(inviteCode)
            // Assigning inside didSet does not re-enter it, so this terminates.
            if normalized != inviteCode { inviteCode = normalized }
        }
    }

    /// The code the user confirmed with "Continue", or nil while still editing.
    /// Non-nil pushes the Join Confirmation screen.
    private(set) var confirmingCode: String?

    init() {}

    // MARK: - Derived state

    /// True when the code has the right shape to be worth sending — the same
    /// check the deep-link parser applies to a code lifted out of a URL, so a
    /// typed code and a tapped one are held to one standard.
    var isCodeValid: Bool {
        InviteLink.isValidCode(inviteCode)
    }

    // MARK: - Actions

    /// Move on to the Join Confirmation screen. A no-op for a malformed code —
    /// the button is disabled then, so this is just the belt to that suspenders.
    func submit() {
        guard isCodeValid else { return }
        confirmingCode = inviteCode
    }

    /// Back on the entry screen (the user cancelled the confirmation or popped it),
    /// so the code is editable again.
    func cancelConfirmation() {
        confirmingCode = nil
    }

    // MARK: - Helpers

    /// Keep only characters the server's alphabet allows and cap the result at 8.
    ///
    /// Casing is left exactly as typed: the API generates codes from a
    /// mixed-case alphabet (`a-zA-Z0-9`) and resolves them with an exact match,
    /// so upper-casing here would turn nearly every real code into a 404 — only
    /// about 1 code in 400 happens to contain no lowercase letter.
    private static func normalize(_ raw: String) -> String {
        String(raw.filter(InviteLink.isCodeCharacter).prefix(InviteLink.codeLength))
    }
}
