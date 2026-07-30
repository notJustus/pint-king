//
//  GroupSwitcherViewModel.swift
//  PintKing
//
//  Drives the group switcher at the top of the Home tab (l3-ios-app.md §"Home
//  Tab"). Shows the Active_Group's name and, on tap, a list of every group the
//  user belongs to; picking one switches the active group.
//
//  Like the other view models, this owns only screen-local state — the fetched
//  `groups` list. The Active_Group is *shared* state that lives on the
//  GroupRepository (l3-ios-app.md §1 "State Ownership"), so `activeGroup` is read
//  straight through the repository rather than cached here; that keeps the
//  switcher in sync when other screens (create/join/leave) change it, and lets
//  @Observable re-render the label for free.
//

import Foundation

@MainActor
@Observable
final class GroupSwitcherViewModel {
    /// The groups the user belongs to, fetched by `load()`. Empty until loaded (or
    /// when the user has no groups) — the view shows its empty state in that case.
    private(set) var groups: [GroupSummary] = []

    private let groupRepository: any GroupRepositoryProtocol

    init(groupRepository: any GroupRepositoryProtocol) {
        self.groupRepository = groupRepository
    }

    /// The current Active_Group, read live from the repository (shared state).
    var activeGroup: Group? {
        groupRepository.activeGroup
    }

    /// The name shown on the switcher, or nil when there's no active group (the
    /// view falls back to its empty state).
    var activeGroupName: String? {
        activeGroup?.name
    }

    /// True when the user belongs to at least one group. When false the view shows
    /// "Join or create a group to get started" with action buttons.
    var hasGroups: Bool {
        !groups.isEmpty
    }

    /// Fetch the user's groups. Failures leave the list empty (surfacing the empty
    /// state) — the switcher has no error affordance of its own; a real fetch error
    /// path arrives with the networking layer (Task 26).
    func load() async {
        groups = (try? await groupRepository.getGroups()) ?? []
    }

    /// Switch the Active_Group to `group`. A no-op if it's already active, so
    /// re-selecting the current group doesn't churn shared state.
    func select(_ group: GroupSummary) async {
        guard group.id != activeGroup?.id else { return }
        try? await groupRepository.switchActiveGroup(groupId: group.id)
    }
}
