//
//  PintLog.swift
//  PintKing
//
//  A single logged pint. Mirrors the `pint_logs` table. `note`, `drinkType`,
//  and `location` are all optional (a photo-only pint is valid — Task 13).
//

import Foundation

struct PintLog: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let groupId: UUID
    let photoUrl: String
    let note: String?
    let drinkType: DrinkType?
    let location: Coordinate?
    let loggedAt: Date
}
