//
//  GroupListViewModel.swift
//  PintKing
//
//  Drives the Group List screen (Profile → My Groups): every group the user
//  belongs to, each with its member count and — where the user is admin — an
//  admin badge, plus entry points to Create / Join (Tasks 20–21) and Group
//  Detail (Task 22).
//
//  Owns only screen-local state — the fetched `groups` list + a first-load
//  `isLoading` flag. Unlike the Home view models it is NOT scoped to the
//  Active_Group: this screen is about *all* memberships, so it never reads
//  `groupRepository.activeGroup`. Groups arrive as `GroupSummary` (the GET
//  /groups shape) carrying the caller's `role` and `memberCount`, so the badge
//  and count are read straight off each row with no extra fetch.
//

import Foundation

@MainActor
@Observable
final class GroupListViewModel {
    /// The user's groups, fetched by `load()`. Empty until loaded (or when the
    /// user has no groups) — the view shows its empty state in that case.
    private(set) var groups: [GroupSummary] = []

    /// True only during the first load, so the view shows skeleton rows once and
    /// pull-to-refresh doesn't blank the list.
    private(set) var isLoading = false

    private let groupRepository: any GroupRepositoryProtocol

    init(groupRepository: any GroupRepositoryProtocol) {
        self.groupRepository = groupRepository
    }

    /// True when the user belongs to at least one group. When false the view
    /// shows an empty state prompting Create / Join.
    var hasGroups: Bool {
        !groups.isEmpty
    }

    /// Fetch the user's groups. First load flips `isLoading` for the skeleton;
    /// failures leave the list empty (surfacing the empty state) — no error
    /// affordance until the networking layer (Task 26).
    func load() async {
        if groups.isEmpty { isLoading = true }
        defer { isLoading = false }
        groups = (try? await groupRepository.getGroups()) ?? []
    }

    /// Pull-to-refresh: same fetch, no skeleton (the list is already populated).
    func refresh() async {
        groups = (try? await groupRepository.getGroups()) ?? []
    }
}
