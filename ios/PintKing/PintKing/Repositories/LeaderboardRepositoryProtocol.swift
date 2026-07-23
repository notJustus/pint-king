//
//  LeaderboardRepositoryProtocol.swift
//  PintKing
//
//  Ranked leaderboard for a group + time period. Maps to
//  GET /groups/{id}/leaderboard?period=… (l3-api.md §1, Leaderboard).
//

import Foundation

@MainActor
protocol LeaderboardRepositoryProtocol: AnyObject {
    /// Ranked entries for a group and period, active members first (by rank),
    /// former members returned unranked for a separate section (Property 23).
    func getLeaderboard(groupId: UUID, period: Period) async throws -> [LeaderboardEntry]
}
