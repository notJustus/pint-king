//
//  ProfileViewModel.swift
//  PintKing
//
//  Drives the Profile tab root (l3-ios-app.md §"Profile Tab", Task 15): the
//  signed-in user's card — avatar (or initials placeholder), display name, and
//  total pints logged — above navigation rows to the profile sub-screens.
//
//  Like the other view models it owns only screen-local state: the loaded `user`
//  and the loading flag. The profile is fetched from UserRepository; the pint
//  total from PintRepository's "all groups" query (groupId: nil), the same fetch
//  the My Pints "All Groups" filter uses. There's no group context here — the
//  card is about the person, not the active group — so nothing is read off the
//  GroupRepository.
//

import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    /// The signed-in user, once `load()` has fetched it. Nil until then; the view
    /// renders an initials placeholder / empty name in the meantime.
    private(set) var user: User?

    /// The user's total pints across every group. Zero until loaded.
    private(set) var totalPintCount = 0

    /// True while the initial fetch is in flight (drives a skeleton/redacted card
    /// on first load, mirroring the Home screens).
    private(set) var isLoading = false

    private let userRepository: any UserRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    init(
        userRepository: any UserRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.pintRepository = pintRepository
    }

    // MARK: - Derived state

    /// The name shown on the card, or "" before the profile loads.
    var displayName: String { user?.displayName ?? "" }

    /// The initials placeholder text (never empty — see InitialsGenerator).
    var initials: String { InitialsGenerator.initials(from: displayName) }

    /// True when there's no avatar to show, so the card falls back to initials.
    /// Real avatar loading needs the networking layer, so today this is effectively
    /// always true; it becomes meaningful once remote images land (Task 26).
    var showsInitialsPlaceholder: Bool { user?.avatarUrl == nil }

    // MARK: - Actions

    /// Fetch the profile and the user's total pint count. Failures leave the card
    /// empty (name blank, count zero) — the real error path arrives with the
    /// networking layer (Task 26), matching the other view models' silent `try?`.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        user = try? await userRepository.getProfile()
        totalPintCount = (try? await pintRepository.getMyPints(groupId: nil))?.count ?? 0
    }

    /// Pull-to-refresh / re-appear: re-fetch profile and count.
    func refresh() async {
        await load()
    }
}
