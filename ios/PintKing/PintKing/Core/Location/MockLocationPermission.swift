//
//  MockLocationPermission.swift
//  PintKing
//
//  In-memory LocationPermissionRequesting for UI development and unit tests.
//  Returns a preset decision and counts how many times it was asked, so tests
//  can assert both the outcome the view model stores and that it actually
//  requested exactly once.
//

import Foundation

@MainActor
@Observable
final class MockLocationPermission: LocationPermissionRequesting {
    /// The answer `request()` will return.
    var decision: LocationPermissionDecision

    /// How many times `request()` has been called.
    private(set) var requestCount = 0

    init(decision: LocationPermissionDecision = .granted) {
        self.decision = decision
    }

    func request() async -> LocationPermissionDecision {
        requestCount += 1
        return decision
    }
}
