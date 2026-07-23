//
//  ProfileSetupViewModel.swift
//  PintKing
//
//  Screen-local state for the first-login Profile Setup screen (l3-ios-app.md
//  §4, User Flows "First Launch"). The user confirms/edits a pre-filled display
//  name, optionally picks an avatar, then taps Continue — which saves the name
//  (and avatar, if chosen) through the UserRepository, requests location
//  permission, and marks setup complete so RootView advances to Home.
//
//  Like LoginViewModel, this owns only screen-local state; the saved profile
//  lives on the UserRepository (the single source of truth). Display-name
//  validation mirrors the API's 1–30-char rule (requirements §1.4); avatar
//  validation reuses the shared ImageValidator so the client fails fast before
//  any upload.
//

import Foundation

@MainActor
@Observable
final class ProfileSetupViewModel {
    /// The editable display name, pre-filled from the current user. Bound to the
    /// text field.
    var displayName: String

    /// The validated avatar bytes to upload, or nil if none chosen. Set only via
    /// `selectAvatar(_:)`, which validates before storing.
    private(set) var avatarData: Data?

    /// True while Continue's save/upload/permission work is in flight; the button
    /// shows a spinner and is disabled.
    private(set) var isSaving = false

    /// Human-readable error shown inline (invalid name, avatar too large/wrong
    /// type, or a failed save), or nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// Flips to true once setup finishes successfully; RootView observes this to
    /// swap Profile Setup for the tab bar.
    private(set) var isComplete = false

    /// The stored location-permission decision: nil until asked, then true
    /// (granted) or false (denied). Denial does not block completion.
    private(set) var locationPermissionGranted: Bool?

    private let userRepository: any UserRepositoryProtocol
    private let locationPermission: any LocationPermissionRequesting

    /// Display-name bounds, matching the API (requirements §1.4).
    private static let nameRange = 1...30

    init(
        initialDisplayName: String,
        userRepository: any UserRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting
    ) {
        self.displayName = initialDisplayName
        self.userRepository = userRepository
        self.locationPermission = locationPermission
    }

    /// The name after trimming leading/trailing whitespace — what actually gets
    /// saved and validated. A name that's only whitespace trims to empty and is
    /// therefore invalid.
    var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the trimmed name is 1–30 characters. The Continue button is
    /// disabled when this is false.
    var isDisplayNameValid: Bool {
        Self.nameRange.contains(trimmedDisplayName.count)
    }

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

    /// Finish setup: validate the name, save it (and the avatar, if any), request
    /// location permission, then mark complete. An invalid name shows an error and
    /// aborts before any repository or permission call. A denied location is
    /// recorded but does not fail setup — location is optional.
    func continueSetup() async {
        guard isDisplayNameValid else {
            errorMessage = "Please enter a name between 1 and 30 characters."
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await userRepository.updateDisplayName(trimmedDisplayName)
            if let avatarData {
                try await userRepository.uploadAvatar(avatarData)
            }
        } catch {
            errorMessage = Self.message(for: error)
            return
        }

        // Location is requested last and never blocks completion — a denial is a
        // normal outcome (the user can still use the app without pin locations).
        let decision = await locationPermission.request()
        locationPermissionGranted = (decision == .granted)

        isComplete = true
    }

    /// Map a thrown error to a human-readable line. Avatar validation errors name
    /// the specific problem; everything else falls back to a generic message
    /// rather than leaking a raw description.
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
