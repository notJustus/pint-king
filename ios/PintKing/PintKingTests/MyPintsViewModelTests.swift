//
//  MyPintsViewModelTests.swift
//  PintKingTests
//
//  Task 17: My Pints. The screen's logic lives in MyPintsViewModel — it fetches
//  the current user's own pints for a group filter (defaulting to the Active_Group,
//  widening to "All Groups"), merges the offline queue's pending / failed rows,
//  deletes within the 24h window, and retries / discards queued pints. These tests
//  drive that logic directly (no View), using the real MockPintRepository for the
//  store and a call-counting spy where asserting the exact call matters.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct MyPintsViewModelTests {

    /// A pint repository spy that returns a fixed confirmed list and records the
    /// group filter each fetch asked for, plus which mutating calls fired. Pending
    /// pints are settable so queue behaviour can be exercised without the real
    /// store.
    private final class SpyPintRepository: PintRepositoryProtocol {
        private(set) var lastGroupFilter: UUID??
        private(set) var deletedId: UUID?
        private(set) var retriedId: UUID?
        private(set) var discardedId: UUID?
        var myPints: [PintLog]
        var deleteError: Error?
        var pendingPints: [PendingPint]

        init(myPints: [PintLog] = [], pending: [PendingPint] = []) {
            self.myPints = myPints
            self.pendingPints = pending
        }

        func getMyPints(groupId: UUID?) async throws -> [PintLog] {
            lastGroupFilter = .some(groupId)
            return groupId == nil ? myPints : myPints.filter { $0.groupId == groupId }
        }

        func deletePint(pintId: UUID) async throws {
            if let deleteError { throw deleteError }
            deletedId = pintId
            myPints.removeAll { $0.id == pintId }
        }

        func retryPint(pintId: UUID) async throws { retriedId = pintId }
        func discardPint(pintId: UUID) async throws {
            discardedId = pintId
            pendingPints.removeAll { $0.id == pintId }
        }

        // Unused by this screen.
        func createPint(groupId: UUID, photoData: Data, note: String?, drinkType: DrinkType?, location: Coordinate?) async throws -> PintLog { fatalError("unused") }
        func getPintsForMember(userId: UUID, groupId: UUID) async throws -> [PintLog] { [] }
        func editPint(pintId: UUID, note: String?, drinkType: DrinkType?) async throws -> PintLog { fatalError("unused") }
    }

    private func makeViewModel(
        pint: any PintRepositoryProtocol,
        group: MockGroupRepository? = nil,
        now: Date = MockData.now
    ) -> MyPintsViewModel {
        MyPintsViewModel(
            groupRepository: group ?? MockGroupRepository(),
            pintRepository: pint,
            now: now
        )
    }

    // MARK: - Filter defaults to the active group

    @Test func loadSeedsFilterFromActiveGroupAndFetchesForIt() async {
        let spy = SpyPintRepository()
        let vm = makeViewModel(pint: spy)

        await vm.load()

        #expect(vm.selectedGroupId == MockData.friday.id)   // the seeded Active_Group
        #expect(spy.lastGroupFilter == .some(MockData.friday.id))
    }

    // MARK: - Group filter changes displayed pints

    @Test func selectingAllGroupsWidensTheFetch() async {
        // Real store: Dave has pints in Friday, Sunday, and Office.
        let vm = makeViewModel(pint: MockPintRepository(pending: []))
        await vm.load()
        let fridayOnly = vm.rows.count

        await vm.selectGroup(nil)   // All Groups

        #expect(vm.selectedGroupId == nil)
        #expect(vm.selectedFilterName == "All Groups")
        #expect(vm.rows.count > fridayOnly)
        #expect(vm.rows.allSatisfy { $0.pint.userId == MockData.daveId })
    }

    @Test func selectingSameGroupIsANoOp() async {
        let spy = SpyPintRepository()
        let vm = makeViewModel(pint: spy)
        await vm.load()   // seeds + fetches for Friday

        await vm.selectGroup(MockData.friday.id)   // already selected

        // No crash / re-seed; filter unchanged.
        #expect(vm.selectedGroupId == MockData.friday.id)
    }

    // MARK: - Pending / failed rows merged from the queue

    @Test func pendingAndFailedPintsAppearWithBadgesAboveConfirmed() async {
        let confirmed = Self.confirmedPint(daysAgo: 3)
        let pending = PendingPint(pint: Self.pint(daysAgo: 0), status: .pending)
        let failed = PendingPint(pint: Self.pint(daysAgo: 0), status: .failed)
        let spy = SpyPintRepository(myPints: [confirmed], pending: [pending, failed])
        let vm = makeViewModel(pint: spy)

        // All fixtures are in Friday Club, the seeded Active_Group, so nothing is
        // filtered out by the default filter.
        await vm.load()

        // Queued rows come first, then confirmed.
        #expect(vm.rows.count == 3)
        #expect(vm.rows[0].status == .pending)
        #expect(vm.rows[1].status == .failed)
        #expect(vm.rows[2].status == .confirmed)
    }

    // MARK: - Delete within the window

    @Test func deleteWithinWindowSucceedsAndRemovesTheRow() async {
        // Dave's most recent Friday Club pint is 1 day ago — inside the window.
        let store = MockPintRepository(pending: [])
        let vm = makeViewModel(pint: store)
        await vm.load()
        let recent = vm.rows.first { vm.canDelete($0.pint) }!
        let before = vm.rows.count

        await vm.delete(pintId: recent.pint.id)

        #expect(vm.rows.count == before - 1)
        #expect(vm.errorMessage == nil)
        #expect(vm.rows.contains { $0.id == recent.id } == false)
    }

    @Test func canDeleteReflectsThe24hWindow() async {
        let vm = makeViewModel(pint: SpyPintRepository())
        let fresh = Self.pint(daysAgo: 0)
        let old = Self.pint(daysAgo: 3)

        #expect(vm.canDelete(fresh))
        #expect(vm.canDelete(old) == false)
    }

    // MARK: - Delete after the window

    @Test func deleteAfterWindowShowsRejectionMessageAndKeepsTheRow() async {
        // Real store rejects with .forbidden outside 24h.
        let store = MockPintRepository(pending: [])
        let vm = makeViewModel(pint: store)
        await vm.load()
        let old = vm.rows.first { !vm.canDelete($0.pint) }!
        let before = vm.rows.count

        await vm.delete(pintId: old.pint.id)

        #expect(vm.errorMessage != nil)
        #expect(vm.rows.count == before)   // still there
    }

    // MARK: - Retry / discard

    @Test func retryReQueuesAFailedPint() async {
        let failed = PendingPint(pint: Self.pint(daysAgo: 0), status: .failed)
        let store = MockPintRepository(pints: [], pending: [failed])
        let vm = makeViewModel(pint: store)
        await vm.load()   // fixture is in Friday Club, the seeded Active_Group
        #expect(vm.rows.first?.status == .failed)

        await vm.retry(pintId: failed.id)

        // The queue flipped the row back to pending; the VM reads it live.
        #expect(vm.rows.first?.status == .pending)
    }

    @Test func discardRemovesAQueuedPint() async {
        let pending = PendingPint(pint: Self.pint(daysAgo: 0), status: .pending)
        let store = MockPintRepository(pints: [], pending: [pending])
        let vm = makeViewModel(pint: store)
        await vm.load()   // fixture is in Friday Club, the seeded Active_Group
        #expect(vm.hasRows)

        await vm.discard(pintId: pending.id)

        #expect(vm.hasRows == false)
    }

    // MARK: - Empty state

    @Test func emptyStateWhenNoPintsOrQueue() async {
        let vm = makeViewModel(pint: SpyPintRepository(myPints: [], pending: []))
        await vm.load()
        #expect(vm.hasRows == false)
    }

    // MARK: - Fixtures

    private static func pint(daysAgo days: Int) -> PintLog {
        PintLog(
            id: UUID(), userId: MockData.daveId, groupId: MockData.fridayId,
            photoUrl: "pints/x.jpg", note: nil, drinkType: nil, location: nil,
            loggedAt: MockData.now.addingTimeInterval(TimeInterval(-days * 86_400))
        )
    }

    private static func confirmedPint(daysAgo days: Int) -> PintLog { pint(daysAgo: days) }
}
