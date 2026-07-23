//
//  LeaderboardViewModel.swift
//  PintKing
//
//  Drives the leaderboard on the Home tab (l3-ios-app.md §"Home Tab",
//  requirements §1). Fetches the ranked board for the Active_Group and a chosen
//  time period, and exposes the split the view renders: active members ranked,
//  former members in a separate greyed section (Property 23).
//
//  Like the other Home view models it owns only screen-local state — the fetched
//  `entries` and the `selectedPeriod`. The Active_Group is *shared* state on the
//  GroupRepository (l3-ios-app.md §1 "State Ownership"), so it's read live rather
//  than cached; switching groups elsewhere re-renders and the next `load()` picks
//  up the new group for free.
//

import Foundation

@MainActor
@Observable
final class LeaderboardViewModel {
    /// The board for the current group + period, active members first (already
    /// rank-ordered by the repository), former members appended unranked. Empty
    /// until `load()` runs, when there's no active group, or when the group has
    /// no pints — the view shows its empty state in that case.
    private(set) var entries: [LeaderboardEntry] = []

    /// The selected time-period filter. Starts on All-Time; changed only via
    /// `select(_:)`, which re-fetches, so it can never drift from `entries`.
    private(set) var selectedPeriod: Period = .allTime

    /// True while a fetch is in flight. The view shows skeleton rows only on the
    /// *first* load (when `entries` is still empty) so a period switch or refresh
    /// doesn't flash the skeleton over existing content.
    private(set) var isLoading = false

    private let groupRepository: any GroupRepositoryProtocol
    private let leaderboardRepository: any LeaderboardRepositoryProtocol

    init(
        groupRepository: any GroupRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol
    ) {
        self.groupRepository = groupRepository
        self.leaderboardRepository = leaderboardRepository
    }

    // MARK: - Derived state

    /// Ranked, currently-in-the-group members — the main list.
    var activeMembers: [LeaderboardEntry] {
        entries.filter { !$0.isFormerMember }
    }

    /// Users who left/were removed but whose pints remain (Property 23). Rendered
    /// below the active list in a greyed "Former Members" section.
    var formerMembers: [LeaderboardEntry] {
        entries.filter(\.isFormerMember)
    }

    var hasFormerMembers: Bool { !formerMembers.isEmpty }

    /// False when there's nothing to show at all — drives the "No pints logged
    /// yet" empty state.
    var hasEntries: Bool { !entries.isEmpty }

    /// The rank delta (movement since the prior period) is only meaningful for a
    /// bounded period, so it's hidden for All-Time (ADR-0064).
    var showsRankDelta: Bool { selectedPeriod != .allTime }

    /// Whether a row wears the crown: rank 1 among active members. Ties at rank 1
    /// all get one (dense ranking), and former members never do.
    func isCrowned(_ entry: LeaderboardEntry) -> Bool {
        !entry.isFormerMember && entry.rank == 1
    }

    // MARK: - Actions

    /// Fetch the board for the Active_Group and current period. With no active
    /// group there's nothing to fetch, so the list is cleared. Failures leave the
    /// list empty (surfacing the empty state) — the real error path lands with the
    /// networking layer (Task 26), matching the other Home view models.
    func load() async {
        guard let groupId = groupRepository.activeGroup?.id else {
            entries = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        entries = (try? await leaderboardRepository.getLeaderboard(
            groupId: groupId, period: selectedPeriod
        )) ?? []
    }

    /// Switch the period filter and re-fetch. A no-op if the period is unchanged,
    /// so re-tapping the current segment doesn't refetch.
    func select(_ period: Period) async {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        await load()
    }

    /// Pull-to-refresh: re-fetch the current group + period.
    func refresh() async {
        await load()
    }
}
