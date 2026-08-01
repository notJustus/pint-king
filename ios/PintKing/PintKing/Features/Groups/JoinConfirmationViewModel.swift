//
//  JoinConfirmationViewModel.swift
//  PintKing
//
//  Screen-local state for the Join Confirmation screen (Task 21, l3-ios-app.md
//  §"Join Confirmation"): the last step before joining, reached from manual code
//  entry today and from an invite deep link later (Task 24). Confirming calls
//  POST /groups/join through the GroupRepository, which — like createGroup — makes
//  the joined group the Active_Group.
//
//  This is where every join outcome lands, because the API resolves an invite code
//  only by attempting the join (Property 11): 404 unknown code, 409 already a
//  member, 403 removed from that group. There is no lookup endpoint, so nothing
//  earlier in the flow can know whether a code is good.
//

import Foundation

@MainActor
@Observable
final class JoinConfirmationViewModel {
    /// The invite code being confirmed. An immutable input, not state — the screen
    /// exists to confirm one specific code.
    let inviteCode: String

    /// True while the join is in flight; the button shows a spinner and is disabled.
    private(set) var isJoining = false

    /// Human-readable error shown inline (unknown code / already a member /
    /// removed), or nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// The group just joined, or nil until the join succeeds. The view observes it
    /// to dismiss the whole join flow; navigating to that group's leaderboard is a
    /// free consequence of it now being active (ADR-0086, ADR-0098).
    private(set) var joinedGroup: Group?

    private let groupRepository: any GroupRepositoryProtocol

    init(inviteCode: String, groupRepository: any GroupRepositoryProtocol) {
        self.inviteCode = inviteCode
        self.groupRepository = groupRepository
    }

    // MARK: - Actions

    /// Join the group behind the invite code. On success the repository sets it
    /// active, so the Home tab re-renders to its leaderboard once the flow dismisses.
    func join() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }

        do {
            joinedGroup = try await groupRepository.joinGroup(inviteCode: inviteCode)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Map a thrown error to a human-readable line. The three join failures are the
    /// API's three documented outcomes (Property 11); anything else is generic.
    private static func message(for error: Error) -> String {
        switch error {
        case APIError.notFound:
            return "Group not found. Check the invite code and try again."
        case APIError.conflict:
            return "You're already a member of this group."
        case APIError.forbidden:
            return "You have been removed from this group and can't rejoin."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
