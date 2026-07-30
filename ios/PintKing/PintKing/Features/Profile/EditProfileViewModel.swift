//
//  EditProfileViewModel.swift
//  PintKing
//
//  Screen-local state for the Edit Profile screen (Task 16, l3-ios-app.md
//  §"Profile Tab"): change the display name and/or avatar. Pre-fills from the
//  current user, validates edits (name 1–30 chars, mirroring the API and the
//  Task 7 setup screen), and on Save writes only what actually changed through
//  the UserRepository.
//
//  Like the other view models it owns only screen-local state; the persisted
//  profile lives on the UserRepository. Display-name validation and avatar
//  validation (5 MB cap, shared ImageValidator) are the same rules as
//  ProfileSetupViewModel — the two screens differ only in that setup also
//  requests location and Edit pre-fills an existing avatar.
//

import Foundation

@MainActor
@Observable
final class EditProfileViewModel {
    /// The editable display name, pre-filled from the current user. Bound to the
    /// text field.
    var displayName: String

    /// The validated avatar bytes to upload, or nil if the user hasn't chosen a
    /// new one this session. Set only via `selectAvatar(_:)`, which validates
    /// before storing. A nil here means "leave the existing avatar untouched" —
    /// it is not "remove the avatar".
    private(set) var avatarData: Data?

    /// True while Save's write/upload work is in flight; the button shows a
    /// spinner and is disabled.
    private(set) var isSaving = false

    /// Human-readable error shown inline (invalid name, avatar too large/wrong
    /// type, or a failed save), or nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// Flips to true once a save finishes successfully; the view observes this to
    /// dismiss back to the Profile tab.
    private(set) var isSaved = false

    /// The name as it was when the screen opened — the baseline for `hasChanges`.
    private let originalDisplayName: String

    private let userRepository: any UserRepositoryProtocol

    /// Display-name bounds, matching the API (requirements §1.4).
    private static let nameRange = 1...30

    init(user: User, userRepository: any UserRepositoryProtocol) {
        self.displayName = user.displayName
        self.originalDisplayName = user.displayName
        self.userRepository = userRepository
    }

    // MARK: - Derived state

    /// The name after trimming leading/trailing whitespace — what actually gets
    /// saved and validated.
    var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the trimmed name is 1–30 characters.
    var isDisplayNameValid: Bool {
        Self.nameRange.contains(trimmedDisplayName.count)
    }

    /// True when the (trimmed) name differs from the original.
    private var nameChanged: Bool {
        trimmedDisplayName != originalDisplayName
    }

    /// True when there's something to save: a renamed profile or a newly chosen
    /// avatar. Drives the Save button's enabled state.
    var hasChanges: Bool {
        nameChanged || avatarData != nil
    }

    // MARK: - Actions

    /// Validate a chosen image and, if it passes, stash it for upload. On failure
    /// the bytes are dropped and an inline error is shown — nothing is uploaded.
    func selectAvatar(_ data: Data) {
        do {
            try ImageValidator.validate(data, as: .avatar)
            avatarData = data
            errorMessage = nil
        } catch {
            avatarData = nil
            errorMessage = Self.message(for: error)
        }
    }

    /// Persist the edits, then mark saved. Writes only what changed — the name is
    /// updated only when it differs, the avatar uploaded only when one was picked
    /// — so saving with no edits is a harmless no-op that still dismisses. An
    /// invalid name shows an error and aborts before any repository call.
    func save() async {
        guard isDisplayNameValid else {
            errorMessage = "Please enter a name between 1 and 30 characters."
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            if nameChanged {
                try await userRepository.updateDisplayName(trimmedDisplayName)
            }
            if let avatarData {
                try await userRepository.uploadAvatar(avatarData)
            }
        } catch {
            errorMessage = Self.message(for: error)
            return
        }

        isSaved = true
    }

    /// Map a thrown error to a human-readable line. Avatar validation errors name
    /// the specific problem; everything else falls back to a generic message.
    private static func message(for error: Error) -> String {
        switch error {
        case ImageValidationError.tooLarge(let maxBytes):
            let mb = maxBytes / (1024 * 1024)
            return "That image is too large. Please choose one under \(mb) MB."
        case ImageValidationError.unsupportedType:
            return "That file isn't a supported image. Please choose a JPEG or PNG."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
