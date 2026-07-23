//
//  MapRepositoryProtocol.swift
//  PintKing
//
//  Bounding-box pint query for the map. Maps to
//  GET /pints/map?group_id=&scope=&sw_lat=&sw_lng=&ne_lat=&ne_lng=
//  (l3-api.md §1, Map). Only pints with a location are ever returned
//  (Property 24c).
//

import Foundation

@MainActor
protocol MapRepositoryProtocol: AnyObject {
    /// Pints whose location falls inside the box [southWest, northEast], for a
    /// group, scoped to the current user (`.personal`) or everyone (`.group`).
    /// Pints without a location are never returned.
    func getPintsInBoundingBox(
        groupId: UUID,
        scope: MapScope,
        southWest: Coordinate,
        northEast: Coordinate
    ) async throws -> [PintLog]
}
