//
//  MockLeaderboardRepository.swift
//  PintKing
//
//  Serves the curated leaderboards from `MockData` for a group + period.
//  Stateless — leaderboards are computed server-side in reality, so the mock
//  just returns fixed boards rather than recomputing from the pint store.
//

import Foundation

@MainActor
@Observable
final class MockLeaderboardRepository: LeaderboardRepositoryProtocol {
    func getLeaderboard(groupId: UUID, period: Period) async throws -> [LeaderboardEntry] {
        MockData.leaderboard(groupId: groupId, period: period)
    }
}
