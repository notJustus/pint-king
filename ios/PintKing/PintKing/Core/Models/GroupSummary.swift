//
//  GroupSummary.swift
//  PintKing
//
//  A group as it appears in the user's group list, matching the API's
//  GET /groups response (`GroupResponse`): the group's identity plus the two
//  list-only fields the screen needs — the caller's own `role` in the group and
//  its `memberCount`. Distinct from `Group` (the mutation return shape, carrying
//  invite metadata) and `GroupDetail` (group + full member list, Task 22): each
//  type maps to the endpoint that produces it, so the list doesn't over-fetch a
//  member array just to show a count.
//

import Foundation

// `Hashable` so the whole summary can ride a NavigationPath as the value-based
// nav value for Group Detail (Task 22) — every field already is.
struct GroupSummary: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    /// The signed-in user's role in this group — drives the admin badge.
    let role: GroupMemberRole
    let memberCount: Int
}
