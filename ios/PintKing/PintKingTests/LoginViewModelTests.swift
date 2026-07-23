//
//  LoginViewModelTests.swift
//  PintKingTests
//
//  Task 6: auth flow. The Login screen's logic lives in LoginViewModel — it
//  drives a mock login, surfaces a human-readable error on failure, and offers
//  a retry that clears the error before trying again. These tests drive that
//  logic directly (no View, no simulator UI), exercising success, failure, and
//  retry against MockAuthRepository's forced-failure switch.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct LoginViewModelTests {

    // MARK: - Success

    @Test func successfulLoginAuthenticates() async {
        let auth = MockAuthRepository()
        let vm = LoginViewModel(authRepository: auth)

        await vm.login()

        #expect(auth.isAuthenticated)
        #expect(auth.currentUser != nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoggingIn == false)
    }

    // MARK: - Failure

    @Test func failedLoginSetsErrorMessage() async {
        let auth = MockAuthRepository()
        auth.shouldFailLogin = true
        let vm = LoginViewModel(authRepository: auth)

        await vm.login()

        #expect(auth.isAuthenticated == false)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoggingIn == false)
    }

    // MARK: - Retry

    @Test func retryClearsErrorAndReattempts() async {
        let auth = MockAuthRepository()
        auth.shouldFailLogin = true
        let vm = LoginViewModel(authRepository: auth)

        await vm.login()
        #expect(vm.errorMessage != nil)

        // The Apple flow now "succeeds" — retry should clear the error and sign in.
        auth.shouldFailLogin = false
        await vm.retry()

        #expect(vm.errorMessage == nil)
        #expect(auth.isAuthenticated)
    }

    @Test func loginClearsAStalePreviousError() async {
        let auth = MockAuthRepository()
        auth.shouldFailLogin = true
        let vm = LoginViewModel(authRepository: auth)
        await vm.login()
        #expect(vm.errorMessage != nil)

        auth.shouldFailLogin = false
        await vm.login()
        #expect(vm.errorMessage == nil)
    }
}
