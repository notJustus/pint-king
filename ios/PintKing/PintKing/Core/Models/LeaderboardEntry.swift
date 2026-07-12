//
//  LeaderboardEntry.swift
//  PintKing
//
//  One ranked row in a group leaderboard. Returned by GET /groups/{id}/leaderboard.
//  `rankDelta` is null for All-Time and for members with no prior-period snapshot
//  (ADR-0064). `isFormerMember` flags a user who left/was removed but whose pints
//  remain — rendered in a separate greyed-out section (Property 23).
//

import Foundation

struct LeaderboardEntry: Codable, Equatable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String
    let avatarUrl: String?
    let pintCount: Int
    let rank: Int
    let rankDelta: Int?
    let isFormerMember: Bool

    // Leaderboard rows are identified by the member they represent.
    var id: UUID { userId }
}
