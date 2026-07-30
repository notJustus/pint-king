//
//  SettingsViewModelTests.swift
//  PintKingTests
//
//  Task 18: the Settings screen's logic — reporting the current location
//  permission and running account deletion — lives in SettingsViewModel, so
//  these tests drive it directly (no View). Deletion delegates to the
//  AuthRepository; the assertion that the session actually ends is on the
//  repository's `isAuthenticated`, since that's what RootView reads to return to
//  Login.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct SettingsViewModelTests {

    private func make(
        auth: MockAuthRepository? = nil,
        location: MockLocationPermission? = nil
    ) -> (SettingsViewModel, MockAuthRepository) {
        let auth = auth ?? MockAuthRepository(authenticated: true)
        let location = location ?? MockLocationPermission(decision: .granted)
        let vm = SettingsViewModel(authRepository: auth, locationPermission: location)
        return (vm, auth)
    }

    // MARK: - Location status

    @Test func locationEnabledReflectsGrantedPermission() {
        let (vm, _) = make(location: MockLocationPermission(decision: .granted))
        #expect(vm.isLocationEnabled)
        #expect(vm.locationStatusText == "Enabled")
    }

    @Test func locationDisabledReflectsDeniedPermission() {
        let (vm, _) = make(location: MockLocationPermission(decision: .denied))
        #expect(!vm.isLocationEnabled)
        #expect(vm.locationStatusText == "Disabled")
    }

    // MARK: - Account deletion

    @Test func deleteAccountCallsRepository() async {
        let (vm, auth) = make()
        await vm.deleteAccount()
        // The mock ends the session on a successful delete.
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }

    @Test func afterDeletionIsAuthenticatedIsFalse() async {
        let auth = MockAuthRepository(authenticated: true)
        let (vm, _) = make(auth: auth)
        #expect(auth.isAuthenticated == true)   // signed in before
        await vm.deleteAccount()
        #expect(auth.isAuthenticated == false)  // gate flips → Login
        #expect(vm.errorMessage == nil)
    }

    @Test func deletionFailureSurfacesErrorAndKeepsSession() async {
        let auth = MockAuthRepository(authenticated: true)
        auth.shouldFailDelete = true
        let (vm, _) = make(auth: auth)
        await vm.deleteAccount()
        #expect(vm.errorMessage != nil)
        // Still signed in — a failed delete must not strand the user at Login.
        #expect(auth.isAuthenticated == true)
    }

    @Test func isDeletingIsFalseAfterCompletion() async {
        let (vm, _) = make()
        await vm.deleteAccount()
        #expect(vm.isDeleting == false)
    }
}
