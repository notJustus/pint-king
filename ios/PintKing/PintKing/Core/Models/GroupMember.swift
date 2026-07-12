//
//  GroupMember.swift
//  PintKing
//
//  A user's membership in a group, denormalised with the display fields the
//  member list needs (name, avatar). Mirrors a `group_members` row joined to
//  its `users` row, as returned by GET /groups/{id}.
//

import Foundation

struct GroupMember: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let groupId: UUID
    let role: GroupMemberRole
    let joinedAt: Date
    let displayName: String
    let avatarUrl: String?
}
