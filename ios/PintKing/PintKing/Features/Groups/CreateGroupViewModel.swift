//
//  CreateGroupViewModel.swift
//  PintKing
//
//  Screen-local state for the Create Group screen (Task 20, requirements §5.1–5.2,
//  l3-ios-app.md §"Group Management"): create a group by name. Validates the name
//  (1–50 chars, mirroring the API) and on Create writes it through the
//  GroupRepository, which makes the new group the Active_Group.
//
//  Like the other view models it owns only screen-local state — the created group
//  and the active-group side effect live on the GroupRepository. The name-validation
//  shape mirrors EditProfileViewModel's (trim-then-count against a range); the range
//  is 1–50 here (group name) vs 1–30 there (display name).
//

import Foundation

@MainActor
@Observable
final class CreateGroupViewModel {
    /// The group name, bound to the text field.
    var name = ""

    /// True while the create call is in flight; the button shows a spinner and is
    /// disabled.
    private(set) var isCreating = false

    /// Human-readable error shown inline (invalid name or a failed create, e.g.
    /// the 99-group limit), or nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// Flips to true once creation succeeds; the view observes this to dismiss
    /// back to wherever the sheet was opened from.
    private(set) var isCreated = false

    private let groupRepository: any GroupRepositoryProtocol

    /// Group-name bounds, matching the API (requirements §5.1).
    private static let nameRange = 1...50

    init(groupRepository: any GroupRepositoryProtocol) {
        self.groupRepository = groupRepository
    }

    // MARK: - Derived state

    /// The name after trimming leading/trailing whitespace — what actually gets
    /// created and validated.
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the trimmed name is 1–50 characters. Drives the Create button's
    /// enabled state.
    var isNameValid: Bool {
        Self.nameRange.contains(trimmedName.count)
    }

    // MARK: - Actions

    /// Create the group, then mark it created. Aborts before any repository call if
    /// the name is invalid. On success the repository sets the new group active, so
    /// the Home tab re-renders to its leaderboard for free once the sheet dismisses.
    func create() async {
        guard isNameValid else {
            errorMessage = "Please enter a name between 1 and 50 characters."
            return
        }

        errorMessage = nil
        isCreating = true
        defer { isCreating = false }

        do {
            _ = try await groupRepository.createGroup(name: trimmedName)
        } catch {
            errorMessage = Self.message(for: error)
            return
        }

        isCreated = true
    }

    /// Map a thrown error to a human-readable line. `.validationFailed` stands in
    /// for the 99-group limit (requirements §5.2); everything else is generic.
    private static func message(for error: Error) -> String {
        switch error {
        case APIError.validationFailed:
            return "You've reached the limit of 99 groups. Leave a group before creating another."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
