//
//  Group.swift
//  PintKing
//
//  A pint-tracking group. Mirrors the `groups` table.
//  Named `Group` — shadows no Swift stdlib type in normal use; if a clash
//  ever arises it can be referenced as `PintKing.Group`.
//

import Foundation

struct Group: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let createdBy: UUID
    let createdAt: Date
}
