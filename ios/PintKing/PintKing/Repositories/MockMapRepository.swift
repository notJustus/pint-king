//
//  MockMapRepository.swift
//  PintKing
//
//  Filters the fixture pints by the requested bounding box and scope, then joins
//  the author in exactly as the API's MapService does (display name, avatar, and
//  the former-member flag derived from the current member list). Mirrors the
//  three parts of Property 24: only pints inside the box are returned, none
//  inside it are dropped, and location-less pints are never returned.
//

import Foundation

@MainActor
@Observable
final class MockMapRepository: MapRepositoryProtocol {
    /// Every query this mock has served, oldest first. The map re-fetches on
    /// each viewport change, so tests need to assert not just *what* came back
    /// but *how often* it was asked for.
    private(set) var queries: [Query] = []

    struct Query: Equatable {
        let groupId: UUID
        let scope: MapScope
        let southWest: Coordinate
        let northEast: Coordinate
    }

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
    ) async throws -> [MapPin] {
        queries.append(Query(groupId: groupId, scope: scope,
                             southWest: southWest, northEast: northEast))

        // A former member is an author with pints in this group but no current
        // membership — the current member list sets the "who's still in" baseline,
        // same derivation as the API.
        let memberIds = Set(MockData.members(of: groupId).map(\.userId))

        return pints.compactMap { pint in
            guard pint.groupId == groupId else { return nil }
            if scope == .personal, pint.userId != currentUserId { return nil }
            guard let location = pint.location else { return nil }   // never return unlocated pints
            guard location.latitude >= southWest.latitude,
                  location.latitude <= northEast.latitude,
                  location.longitude >= southWest.longitude,
                  location.longitude <= northEast.longitude
            else { return nil }

            return MapPin(
                id: pint.id,
                userId: pint.userId,
                displayName: MockData.displayName(pint.userId),
                avatarUrl: nil,
                isFormerMember: !memberIds.contains(pint.userId),
                photoUrl: pint.photoUrl,
                note: pint.note,
                drinkType: pint.drinkType,
                latitude: location.latitude,
                longitude: location.longitude,
                loggedAt: pint.loggedAt
            )
        }
    }
}
