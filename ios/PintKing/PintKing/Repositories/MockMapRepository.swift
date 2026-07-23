//
//  MockMapRepository.swift
//  PintKing
//
//  Filters the fixture pints by the requested bounding box and scope. Mirrors
//  the three parts of Property 24: only pints inside the box are returned, none
//  inside it are dropped, and location-less pints are never returned.
//

import Foundation

@MainActor
@Observable
final class MockMapRepository: MapRepositoryProtocol {
    private let pints: [PintLog]
    private let currentUserId: UUID

    init(pints: [PintLog] = MockData.pints, currentUserId: UUID = MockData.currentUser.id) {
        self.pints = pints
        self.currentUserId = currentUserId
    }

    func getPintsInBoundingBox(
        groupId: UUID,
        scope: MapScope,
        southWest: Coordinate,
        northEast: Coordinate
    ) async throws -> [PintLog] {
        pints.filter { pint in
            guard pint.groupId == groupId else { return false }
            if scope == .personal, pint.userId != currentUserId { return false }
            guard let loc = pint.location else { return false }   // never return unlocated pints
            return loc.latitude >= southWest.latitude
                && loc.latitude <= northEast.latitude
                && loc.longitude >= southWest.longitude
                && loc.longitude <= northEast.longitude
        }
    }
}
