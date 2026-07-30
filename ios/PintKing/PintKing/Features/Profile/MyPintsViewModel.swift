//
//  MyPintsViewModel.swift
//  PintKing
//
//  Drives the My Pints screen (l3-ios-app.md §"Profile Tab", Task 17): the signed-
//  in user's own pints across groups, with a group filter, per-pint edit / delete,
//  and the offline queue's pending / failed rows. Like the other view models it
//  owns only screen-local state — the fetched confirmed pints, the loading flag,
//  the current filter, and an inline error — while the pints live on the
//  PintRepository and the group list on the GroupRepository.
//
//  Two things distinguish it from the Home history screens:
//
//  1. It is *not* scoped to the Active_Group. The group filter defaults to the
//     active group but the user can widen it to "All Groups" (or pick another),
//     so `selectedGroupId` is real screen state (nil == all groups), threaded
//     straight into `getMyPints(groupId:)` which already treats nil as "all".
//
//  2. It merges the offline queue. `pendingPints` is read *live* off the repository
//     (a computed pass-through, so retry / discard re-render for free) and shown
//     above the confirmed history with a "pending" / "failed" badge — never on the
//     leaderboard or map (ADR-0025).
//
//  Delete enforces the 24h window (Property 19): the repository is the source of
//  truth (it throws `.forbidden` outside the window), and the view model both maps
//  that to a human message and exposes `canDelete(_:)` so the view can show a
//  destructive confirmation only when the delete would actually succeed.
//

import Foundation

@MainActor
@Observable
final class MyPintsViewModel {
    /// The user's confirmed pints for the current filter, newest first (the order
    /// the repository returns). Excludes queued pints — those come from
    /// `pendingPints`. Empty until `load()` runs.
    private(set) var pints: [PintLog] = []

    /// The groups the user belongs to, for the filter dropdown. Fetched in `load()`.
    private(set) var groups: [Group] = []

    /// The active filter: a group id, or nil for "All Groups". Defaults to the
    /// Active_Group on first load, then follows the user's selection.
    private(set) var selectedGroupId: UUID?

    /// True while the confirmed-pint fetch is in flight; drives skeleton rows on
    /// the first load only (mirrors the history screens).
    private(set) var isLoading = false

    /// Human-readable error shown inline — a rejected delete (outside the 24h
    /// window) or a failed action. Nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// Set once the initial filter has been seeded from the Active_Group, so a
    /// later `load()` (e.g. after an edit) doesn't clobber the user's choice.
    private var didSeedFilter = false

    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    /// "Now" for the 24h delete window's UX gate (`canDelete`). Defaults to the
    /// wall clock; tests pass `MockData.now` so the static fixtures are stable.
    /// The repository enforces the real window regardless of this value.
    private let now: Date

    init(
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        now: Date = Date()
    ) {
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
        self.now = now
    }

    // MARK: - Derived state

    /// The queued pints for the current filter, read live off the repository so
    /// retry / discard re-render without a manual refetch.
    private var pendingPints: [PendingPint] {
        pintRepository.pendingPints.filter {
            selectedGroupId == nil || $0.pint.groupId == selectedGroupId
        }
    }

    /// The rows to render: queued pints first (they want attention), then the
    /// confirmed history. Each row carries the group name and its upload status so
    /// the view can badge it and choose the right swipe actions.
    var rows: [MyPintRow] {
        let pending = pendingPints.map {
            MyPintRow(
                pint: $0.pint,
                groupName: groupName(for: $0.pint.groupId),
                status: $0.status == .pending ? .pending : .failed
            )
        }
        let confirmed = pints.map {
            MyPintRow(pint: $0, groupName: groupName(for: $0.groupId), status: .confirmed)
        }
        return pending + confirmed
    }

    /// False when there's nothing to show for the current filter — drives the
    /// empty state.
    var hasRows: Bool { !rows.isEmpty }

    /// The label for the current filter, shown on the dropdown button.
    var selectedFilterName: String {
        guard let selectedGroupId else { return "All Groups" }
        return groupName(for: selectedGroupId)
    }

    /// True when a pint is still inside the 24h edit/delete window — the view uses
    /// this to show a destructive delete confirmation vs. a plain rejection message.
    func canDelete(_ pint: PintLog) -> Bool {
        now.timeIntervalSince(pint.loggedAt) <= 24 * 60 * 60
    }

    // MARK: - Loading & filtering

    /// Fetch the group list and the confirmed pints for the current filter. On the
    /// first load the filter is seeded from the Active_Group. Failures leave the
    /// lists empty (surfacing the empty state) — the real error path lands with
    /// networking (Task 26), matching the other view models' silent `try?`.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        groups = (try? await groupRepository.getGroups()) ?? []
        if !didSeedFilter {
            selectedGroupId = groupRepository.activeGroup?.id
            didSeedFilter = true
        }
        await fetchPints()
    }

    /// Pull-to-refresh / re-appear: re-fetch without re-seeding the filter.
    func refresh() async {
        groups = (try? await groupRepository.getGroups()) ?? []
        await fetchPints()
    }

    /// Change the group filter (nil == All Groups) and re-fetch. A no-op when the
    /// filter is unchanged.
    func selectGroup(_ groupId: UUID?) async {
        guard groupId != selectedGroupId else { return }
        selectedGroupId = groupId
        await fetchPints()
    }

    private func fetchPints() async {
        pints = (try? await pintRepository.getMyPints(groupId: selectedGroupId)) ?? []
    }

    // MARK: - Delete

    /// Delete a confirmed pint. The repository enforces the 24h window and throws
    /// `.forbidden` outside it, which we surface as a message; on success the list
    /// is re-fetched so the row disappears.
    func delete(pintId: UUID) async {
        errorMessage = nil
        do {
            try await pintRepository.deletePint(pintId: pintId)
            await fetchPints()
        } catch APIError.forbidden {
            errorMessage = "Pints can only be deleted within 24 hours of logging."
        } catch {
            errorMessage = "Couldn't delete that pint. Please try again."
        }
    }

    // MARK: - Offline queue actions

    /// Re-queue a failed pint for upload.
    func retry(pintId: UUID) async {
        errorMessage = nil
        try? await pintRepository.retryPint(pintId: pintId)
    }

    /// Drop a queued pint from the local queue.
    func discard(pintId: UUID) async {
        errorMessage = nil
        try? await pintRepository.discardPint(pintId: pintId)
    }

    // MARK: - Helpers

    /// The display name of a group by id, or "Unknown group" if it isn't in the
    /// user's list (e.g. a pint in a group they've since left).
    private func groupName(for groupId: UUID) -> String {
        groups.first { $0.id == groupId }?.name ?? "Unknown group"
    }
}

/// One row in the My Pints list: a pint plus the group it belongs to and its
/// upload status. Built by the view model so the view stays a thin renderer.
struct MyPintRow: Identifiable, Equatable {
    /// Where the pint is in its lifecycle: confirmed by the server, or queued
    /// locally (pending upload / failed after retries).
    enum Status: Equatable {
        case confirmed
        case pending
        case failed
    }

    let pint: PintLog
    let groupName: String
    let status: Status

    var id: UUID { pint.id }
}
