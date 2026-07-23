//
//  LeaderboardViewModelTests.swift
//  PintKingTests
//
//  Task 9: leaderboard. The screen's logic lives in LeaderboardViewModel — it
//  fetches the board for the Active_Group and the selected period, re-fetches
//  when the period changes or on pull-to-refresh, splits active from former
//  members, hides the rank delta for All-Time, and flags rank-1 rows for the
//  crown. These tests drive that logic directly (no View), using a call-counting
//  spy to assert re-fetches and the seeded MockData boards for the split/crown.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct LeaderboardViewModelTests {

    /// Records every fetch (count + last arguments) and returns a fixed board, so
    /// tests can assert *that* a re-fetch happened and *what* it asked for.
    private final class SpyLeaderboardRepository: LeaderboardRepositoryProtocol {
        private(set) var fetchCount = 0
        private(set) var lastGroupId: UUID?
        private(set) var lastPeriod: Period?
        var entries: [LeaderboardEntry]

        init(entries: [LeaderboardEntry] = []) { self.entries = entries }

        func getLeaderboard(groupId: UUID, period: Period) async throws -> [LeaderboardEntry] {
            fetchCount += 1
            lastGroupId = groupId
            lastPeriod = period
            return entries
        }
    }

    private func makeViewModel(
        leaderboard: any LeaderboardRepositoryProtocol,
        group: MockGroupRepository? = nil
    ) -> LeaderboardViewModel {
        LeaderboardViewModel(
            groupRepository: group ?? MockGroupRepository(),
            leaderboardRepository: leaderboard
        )
    }

    // MARK: - Fetching for the active group + period

    @Test func loadFetchesForActiveGroupAndSelectedPeriod() async {
        let spy = SpyLeaderboardRepository(entries: MockData.leaderboard(groupId: MockData.fridayId, period: .allTime))
        let vm = makeViewModel(leaderboard: spy)

        await vm.load()

        #expect(spy.fetchCount == 1)
        #expect(spy.lastGroupId == MockData.friday.id)   // seeded Active_Group
        #expect(spy.lastPeriod == .allTime)              // default period
        #expect(vm.entries.isEmpty == false)
    }

    @Test func noActiveGroupYieldsEmptyWithoutFetching() async {
        let spy = SpyLeaderboardRepository()
        let noGroups = MockGroupRepository(groups: [], activeGroupId: nil)
        let vm = makeViewModel(leaderboard: spy, group: noGroups)

        await vm.load()

        #expect(spy.fetchCount == 0)
        #expect(vm.entries.isEmpty)
    }

    // MARK: - Period switching

    @Test func periodSwitchTriggersRefetch() async {
        let spy = SpyLeaderboardRepository()
        let vm = makeViewModel(leaderboard: spy)
        await vm.load()
        #expect(spy.fetchCount == 1)

        await vm.select(.thisWeek)

        #expect(vm.selectedPeriod == .thisWeek)
        #expect(spy.fetchCount == 2)
        #expect(spy.lastPeriod == .thisWeek)
    }

    @Test func selectingTheCurrentPeriodIsANoOp() async {
        let spy = SpyLeaderboardRepository()
        let vm = makeViewModel(leaderboard: spy)
        await vm.load()

        await vm.select(.allTime)   // already selected

        #expect(spy.fetchCount == 1)
    }

    // MARK: - Rank delta visibility

    @Test func rankDeltaHiddenForAllTimeOnly() async {
        let vm = makeViewModel(leaderboard: SpyLeaderboardRepository())
        #expect(vm.selectedPeriod == .allTime)
        #expect(vm.showsRankDelta == false)

        await vm.select(.thisWeek)
        #expect(vm.showsRankDelta == true)

        await vm.select(.thisMonth)
        #expect(vm.showsRankDelta == true)
    }

    // MARK: - Crown for rank 1 (all rank-1 rows, ties included)

    @Test func crownShownForEveryRankOneEntry() async {
        // Friday Club has a rank-1 tie (Dave + Emma), so both must be crowned.
        let vm = makeViewModel(leaderboard: MockLeaderboardRepository())
        await vm.load()

        let crowned = vm.activeMembers.filter { vm.isCrowned($0) }
        #expect(crowned.count == 2)
        #expect(crowned.allSatisfy { $0.rank == 1 })
    }

    // MARK: - Active vs former members

    @Test func formerMembersSeparatedFromActive() async {
        // Friday Club's board includes Fred, a former member.
        let vm = makeViewModel(leaderboard: MockLeaderboardRepository())
        await vm.load()

        #expect(vm.activeMembers.allSatisfy { $0.isFormerMember == false })
        #expect(vm.formerMembers.count == 1)
        #expect(vm.formerMembers.first?.userId == MockData.fredId)
        #expect(vm.hasFormerMembers)
    }

    // MARK: - Empty state

    @Test func emptyStateWhenNoEntries() async {
        let spy = SpyLeaderboardRepository(entries: [])
        let vm = makeViewModel(leaderboard: spy)
        await vm.load()

        #expect(vm.hasEntries == false)
        #expect(vm.activeMembers.isEmpty)
        #expect(vm.formerMembers.isEmpty)
    }

    // MARK: - Pull-to-refresh

    @Test func refreshTriggersRefetch() async {
        let spy = SpyLeaderboardRepository()
        let vm = makeViewModel(leaderboard: spy)
        await vm.load()
        #expect(spy.fetchCount == 1)

        await vm.refresh()

        #expect(spy.fetchCount == 2)
        #expect(spy.lastPeriod == .allTime)   // refresh keeps the current period
    }
}
