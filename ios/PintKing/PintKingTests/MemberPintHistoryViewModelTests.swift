//
//  MemberPintHistoryViewModelTests.swift
//  PintKingTests
//
//  Task 10: Member Pint History. The screen's logic lives in
//  MemberPintHistoryViewModel — it fetches a member's pints for the *Active_Group*
//  (read live from the group repository, not a passed id), exposes them newest
//  first, and reports whether there's anything to show. These tests drive that
//  logic directly (no View), using a call-counting spy to assert the fetch key
//  (member + active group) and the seeded MockData pints for the content.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct MemberPintHistoryViewModelTests {

    /// Records every fetch (count + last arguments) and returns a fixed list, so
    /// tests can assert *that* a fetch happened and *what member/group* it asked
    /// for. Only `getPintsForMember` is exercised; the rest satisfy the protocol.
    private final class SpyPintRepository: PintRepositoryProtocol {
        private(set) var fetchCount = 0
        private(set) var lastUserId: UUID?
        private(set) var lastGroupId: UUID?
        var pintsToReturn: [PintLog]
        private(set) var pendingPints: [PendingPint] = []

        init(pintsToReturn: [PintLog] = []) { self.pintsToReturn = pintsToReturn }

        func getPintsForMember(userId: UUID, groupId: UUID) async throws -> [PintLog] {
            fetchCount += 1
            lastUserId = userId
            lastGroupId = groupId
            return pintsToReturn
        }

        // Unused by this screen.
        func createPint(groupId: UUID, photoData: Data, note: String?, drinkType: DrinkType?, location: Coordinate?) async throws -> PintLog { fatalError("unused") }
        func getMyPints(groupId: UUID?) async throws -> [PintLog] { [] }
        func editPint(pintId: UUID, note: String?, drinkType: DrinkType?) async throws -> PintLog { fatalError("unused") }
        func deletePint(pintId: UUID) async throws {}
        func retryPint(pintId: UUID) async throws {}
        func discardPint(pintId: UUID) async throws {}
    }

    private func makeViewModel(
        userId: UUID = MockData.daveId,
        memberName: String = "Dave Smith",
        pint: any PintRepositoryProtocol,
        group: MockGroupRepository? = nil
    ) -> MemberPintHistoryViewModel {
        MemberPintHistoryViewModel(
            userId: userId,
            memberName: memberName,
            groupRepository: group ?? MockGroupRepository(),
            pintRepository: pint
        )
    }

    // MARK: - Fetching for the member + active group

    @Test func loadFetchesForMemberAndActiveGroup() async {
        let spy = SpyPintRepository(pintsToReturn: [Self.samplePint])
        let vm = makeViewModel(userId: MockData.emmaId, memberName: "Emma Byrne", pint: spy)

        await vm.load()

        #expect(spy.fetchCount == 1)
        #expect(spy.lastUserId == MockData.emmaId)      // the selected member
        #expect(spy.lastGroupId == MockData.friday.id)  // the seeded Active_Group
        #expect(vm.hasPints)
    }

    @Test func noActiveGroupYieldsEmptyWithoutFetching() async {
        let spy = SpyPintRepository(pintsToReturn: [Self.samplePint])
        let noGroups = MockGroupRepository(groups: [], activeGroupId: nil)
        let vm = makeViewModel(pint: spy, group: noGroups)

        await vm.load()

        #expect(spy.fetchCount == 0)
        #expect(vm.pints.isEmpty)
        #expect(vm.hasPints == false)
    }

    // MARK: - Content

    @Test func entriesDisplayTheMembersPintsForTheGroup() async {
        // Real mock repo: Dave logged 3 pints in Friday Club (the Active_Group).
        let vm = makeViewModel(pint: MockPintRepository())

        await vm.load()

        #expect(vm.pints.count == 3)
        #expect(vm.pints.allSatisfy { $0.userId == MockData.daveId })
        #expect(vm.pints.allSatisfy { $0.groupId == MockData.friday.id })
    }

    @Test func memberNameIsExposedAsTitle() {
        let vm = makeViewModel(memberName: "Emma Byrne", pint: SpyPintRepository())
        #expect(vm.memberName == "Emma Byrne")
    }

    // MARK: - Empty state

    @Test func emptyStateWhenMemberHasNoPintsInGroup() async {
        // Sophia is only in Office Crew, so she has no pints in Friday Club.
        let vm = makeViewModel(
            userId: MockData.sophiaId, memberName: "Sophia Marchetti",
            pint: MockPintRepository()
        )

        await vm.load()

        #expect(vm.pints.isEmpty)
        #expect(vm.hasPints == false)
    }

    // MARK: - Refresh

    @Test func refreshRefetchesForTheSameMemberAndGroup() async {
        let spy = SpyPintRepository()
        let vm = makeViewModel(userId: MockData.emmaId, memberName: "Emma Byrne", pint: spy)
        await vm.load()
        #expect(spy.fetchCount == 1)

        await vm.refresh()

        #expect(spy.fetchCount == 2)
        #expect(spy.lastUserId == MockData.emmaId)
        #expect(spy.lastGroupId == MockData.friday.id)
    }

    // MARK: - Fixtures

    private static let samplePint = PintLog(
        id: UUID(), userId: MockData.emmaId, groupId: MockData.fridayId,
        photoUrl: "pints/x.jpg", note: "Sample", drinkType: .lager,
        location: nil, loggedAt: MockData.now
    )
}
