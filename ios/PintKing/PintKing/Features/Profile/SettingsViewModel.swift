//
//  SettingsViewModel.swift
//  PintKing
//
//  Screen-local state for the Settings screen (Task 18): the location-permission
//  row and account deletion. Like the other feature view models, it owns only
//  transient screen state — the source of truth for "am I still signed in?" is
//  the AuthRepository, which `deleteAccount()` flips so RootView returns to Login
//  for free (same declarative gate as logout).
//
//  Location here is read-only: the app can't toggle the system permission
//  programmatically, so the row just reflects the current status and deep-links
//  to iOS Settings (the view owns the deep-link; this VM owns only the reading).
//

import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    /// True while the account-deletion cascade is in flight; the confirm button
    /// shows a spinner and is disabled.
    private(set) var isDeleting = false

    /// Human-readable error shown inline when deletion fails, or nil otherwise.
    private(set) var errorMessage: String?

    private let authRepository: any AuthRepositoryProtocol
    private let locationPermission: any LocationPermissionRequesting

    init(
        authRepository: any AuthRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting
    ) {
        self.authRepository = authRepository
        self.locationPermission = locationPermission
    }

    /// Whether location access is currently granted, read live from the
    /// permission (no prompt). Drives the status label on the location row.
    var isLocationEnabled: Bool {
        locationPermission.status == .granted
    }

    /// The short status text shown on the location row.
    var locationStatusText: String {
        isLocationEnabled ? "Enabled" : "Disabled"
    }

    /// Permanently delete the account. On success the repository clears the
    /// session, so RootView swaps back to Login — this VM has nothing more to do.
    /// On failure the error surfaces inline and the user stays on Settings.
    func deleteAccount() async {
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await authRepository.deleteAccount()
        } catch {
            errorMessage = "Couldn't delete your account. Please try again."
        }
    }
}
