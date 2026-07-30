//
//  MockLocationProvider.swift
//  PintKing
//
//  In-memory LocationProviding for UI development and unit tests. Returns a preset
//  coordinate (or nil, to stand in for a timeout / denied / error) and counts how
//  many times it was asked, so tests can assert both what the view model attaches
//  to the pint and that it asked for location exactly once.
//

import Foundation

@MainActor
@Observable
final class MockLocationProvider: LocationProviding {
    /// The coordinate `currentLocation()` returns; nil stands in for the
    /// timeout / denied / error paths (all of which the real service maps to nil).
    var location: Coordinate?

    /// How many times `currentLocation()` has been called.
    private(set) var requestCount = 0

    init(location: Coordinate? = nil) {
        self.location = location
    }

    func currentLocation() async -> Coordinate? {
        requestCount += 1
        return location
    }
}
