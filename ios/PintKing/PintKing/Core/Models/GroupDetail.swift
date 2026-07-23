//
//  GroupDetail.swift
//  PintKing
//
//  A group together with its full member list, as returned by GET /groups/{id}.
//  `Group` alone (from GET /groups) is enough for the group list; the detail
//  screen (Task 22) additionally needs the members, so the two are kept as
//  separate shapes matching the two endpoints.
//

import Foundation

struct GroupDetail: Codable, Equatable, Identifiable, Sendable {
    let group: Group
    let members: [GroupMember]

    // Identified by the underlying group.
    var id: UUID { group.id }
}
