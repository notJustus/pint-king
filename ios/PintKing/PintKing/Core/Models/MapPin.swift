//
//  MapPin.swift
//  PintKing
//
//  One pint rendered as a map pin. Mirrors the `MapPin` response of
//  GET /pints/map (l3-api.md §1, Map) — which is deliberately NOT a `PintLog`:
//  the endpoint joins the author in (display name, avatar, whether they've since
//  left the group) so the map can draw a labelled, correctly-greyed pin without
//  a second fetch, and it drops the optionality from the location because pints
//  without one are filtered out server-side (Property 24c).
//
//  Third group of "one type per endpoint" alongside GroupSummary / Group /
//  GroupDetail (ADR-0079).
//

import Foundation

struct MapPin: Codable, Equatable, Identifiable, Sendable {
    /// The pint's id — the pin *is* a pint, so pins are identified by it.
    let id: UUID
    let userId: UUID
    let displayName: String
    let avatarUrl: String?
    /// The author left (or was removed from) the group but their pints remain,
    /// so the pin renders greyed-out and visually distinct (Property 23).
    let isFormerMember: Bool
    let photoUrl: String
    let note: String?
    let drinkType: DrinkType?
    /// Non-optional: the endpoint never returns a pint without a location.
    let latitude: Double
    let longitude: Double
    let loggedAt: Date
}
