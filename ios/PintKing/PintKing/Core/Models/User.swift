//
//  User.swift
//  PintKing
//
//  The authenticated user's profile. Mirrors the `users` table / GET /users/me.
//

import Foundation

struct User: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let appleId: String
    let displayName: String
    let avatarUrl: String?
    let activeGroupId: UUID?
}
