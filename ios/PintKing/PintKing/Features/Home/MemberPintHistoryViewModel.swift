//
//  MemberPintHistoryViewModel.swift
//  PintKing
//
//  Drives the Member Pint History screen (l3-ios-app.md §"Home Tab", Task 10):
//  tap a member on the leaderboard, see the pints they've logged *in the active
//  group*. Like the other Home view models it owns only screen-local state — the
//  fetched `pints` and the loading flag — and reads the Active_Group *live* from
//  the GroupRepository (shared state with a single owner, l3-ios-app.md §1) rather
//  than caching it, so the fetch always targets the group currently on screen.
//
//  The member is fixed for the screen's lifetime: `userId` is the fetch key,
//  `memberName` the navigation title. Both are passed in from the tapped row.
//

import Foundation

@MainActor
@Observable
final class MemberPintHistoryViewModel {
    /// The member whose history this screen shows — the navigation title.
    let memberName: String

    /// The member's pints in the Active_Group, newest first (the order the
    /// repository returns). Empty until `load()` runs, when there's no active
    /// group, or when the member has logged nothing here — the view shows its
    /// empty state in that case.
    private(set) var pints: [PintLog] = []

    /// True while a fetch is in flight. The view shows skeleton rows only on the
    /// first load (when `pints` is still empty) so a pull-to-refresh doesn't flash
    /// the skeleton over existing content.
    private(set) var isLoading = false

    private let userId: UUID
    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    init(
        userId: UUID,
        memberName: String,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        self.userId = userId
        self.memberName = memberName
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
    }

    // MARK: - Derived state

    /// False when the member has no pints to show — drives the empty state.
    var hasPints: Bool { !pints.isEmpty }

    // MARK: - Actions

    /// Fetch the member's pints for the Active_Group. With no active group there's
    /// nothing to fetch, so the list is cleared. Failures leave the list empty
    /// (surfacing the empty state) — the real error path lands with the networking
    /// layer (Task 26), matching the other Home view models.
    func load() async {
        guard let groupId = groupRepository.activeGroup?.id else {
            pints = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        pints = (try? await pintRepository.getPintsForMember(
            userId: userId, groupId: groupId
        )) ?? []
    }

    /// Pull-to-refresh: re-fetch the member's pints for the current active group.
    func refresh() async {
        await load()
    }
}
