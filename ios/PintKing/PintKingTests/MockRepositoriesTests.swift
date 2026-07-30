//
//  MockRepositoriesTests.swift
//  PintKingTests
//
//  Task 3: repository protocols + mock implementations. These tests verify the
//  mocks return the expected hardcoded data and that stateful mutations (login,
//  rename, switch/join/leave group, create/edit/delete pint) behave. Each mock is
//  driven through its PROTOCOL type — the variable is typed as e.g.
//  `AuthRepositoryProtocol`, not `MockAuthRepository` — so conformance is proven
//  by the code compiling and the calls dispatching.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct MockRepositoriesTests {

    // MARK: - Auth

    @Test func authStartsSignedOut() async throws {
        let auth: AuthRepositoryProtocol = MockAuthRepository()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }

    @Test func loginAuthenticatesAndSetsCurrentUser() async throws {
        let auth: AuthRepositoryProtocol = MockAuthRepository()
        try await auth.login()
        #expect(auth.isAuthenticated == true)
        #expect(auth.currentUser == MockData.currentUser)
    }

    @Test func loginCanBeForcedToFail() async throws {
        let mock = MockAuthRepository()
        mock.shouldFailLogin = true
        await #expect(throws: APIError.serverError) { try await mock.login() }
        #expect(mock.isAuthenticated == false)
    }

    @Test func logoutClearsSession() async throws {
        let auth: AuthRepositoryProtocol = MockAuthRepository(authenticated: true)
        #expect(auth.isAuthenticated == true)
        try await auth.logout()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }

    // MARK: - User

    @Test func getProfileReturnsCurrentUser() async throws {
        let user: UserRepositoryProtocol = MockUserRepository()
        #expect(try await user.getProfile() == MockData.currentUser)
    }

    @Test func updateDisplayNamePersists() async throws {
        let user: UserRepositoryProtocol = MockUserRepository()
        let updated = try await user.updateDisplayName("New Name")
        #expect(updated.displayName == "New Name")
        // Persisted for subsequent reads.
        #expect(try await user.getProfile() == updated)
    }

    @Test func uploadAvatarChangesUrl() async throws {
        let user: UserRepositoryProtocol = MockUserRepository()
        let before = try await user.getProfile()
        let after = try await user.uploadAvatar(Data([0xFF, 0xD8]))
        #expect(after.avatarUrl != before.avatarUrl)
        #expect(after.avatarUrl != nil)
    }

    // MARK: - Group

    @Test func getGroupsReturnsThreeGroups() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let groups = try await group.getGroups()
        #expect(groups.count == 3)
        #expect(groups.contains { $0.name == "Friday Club" })
    }

    @Test func activeGroupStartsOnFridayClub() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        #expect(group.activeGroup?.id == MockData.fridayId)
    }

    @Test func getGroupDetailReturnsMembers() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let detail = try await group.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.group.id == MockData.fridayId)
        #expect(detail.members.count == 4)
        // Dave is the admin of Friday Club.
        let dave = detail.members.first { $0.userId == MockData.daveId }
        #expect(dave?.role == .admin)
    }

    @Test func getGroupDetailForUnknownGroupThrowsNotFound() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        await #expect(throws: APIError.notFound) {
            _ = try await group.getGroupDetail(groupId: UUID())
        }
    }

    @Test func switchActiveGroupUpdatesState() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        try await group.switchActiveGroup(groupId: MockData.sundayId)
        #expect(group.activeGroup?.id == MockData.sundayId)
    }

    @Test func switchToUnknownGroupThrows() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        await #expect(throws: APIError.notFound) {
            try await group.switchActiveGroup(groupId: UUID())
        }
    }

    @Test func createGroupAppendsAndBecomesActive() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let created = try await group.createGroup(name: "New Crew")
        #expect(created.name == "New Crew")
        #expect(group.activeGroup?.id == created.id)
        #expect(try await group.getGroups().count == 4)
        // Creator is admin.
        let detail = try await group.getGroupDetail(groupId: created.id)
        #expect(detail.members.first?.role == .admin)
    }

    @Test func joinGroupWithValidCodeSucceedsAndBecomesActive() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let joined = try await group.joinGroup(inviteCode: MockData.joinableInviteCode)
        #expect(joined.id == MockData.joinableGroup.id)
        #expect(group.activeGroup?.id == joined.id)
    }

    @Test func joinGroupWithUnknownCodeThrowsNotFound() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        await #expect(throws: APIError.notFound) {
            _ = try await group.joinGroup(inviteCode: "NOPENOPE")
        }
    }

    @Test func joinGroupAlreadyMemberThrowsConflict() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        // Friday Club's code — the user is already in it.
        await #expect(throws: APIError.conflict) {
            _ = try await group.joinGroup(inviteCode: MockData.friday.inviteCode)
        }
    }

    @Test func leaveActiveGroupFallsBackToAnotherGroup() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        // Active is Friday Club (created 120d ago). After leaving, the most
        // recently created remaining group (Office Crew, 40d) becomes active.
        try await group.leaveGroup(groupId: MockData.fridayId)
        #expect(try await group.getGroups().count == 2)
        #expect(group.activeGroup?.id == MockData.officeId)
    }

    @Test func removeMemberDropsThemFromDetail() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        try await group.removeMember(groupId: MockData.fridayId, userId: MockData.emmaId)
        let detail = try await group.getGroupDetail(groupId: MockData.fridayId)
        #expect(detail.members.contains { $0.userId == MockData.emmaId } == false)
    }

    @Test func promoteMemberMakesThemAdmin() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        try await group.promoteMember(groupId: MockData.fridayId, userId: MockData.emmaId)
        let detail = try await group.getGroupDetail(groupId: MockData.fridayId)
        let emma = detail.members.first { $0.userId == MockData.emmaId }
        #expect(emma?.role == .admin)
    }

    @Test func regenerateInviteCodeChangesCode() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let before = try await group.getGroups().first { $0.id == MockData.fridayId }!.inviteCode
        let after = try await group.regenerateInviteCode(groupId: MockData.fridayId)
        #expect(after.inviteCode != before)
        #expect(after.inviteCode.count == 8)
    }

    @Test func updateGroupNamePersists() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository()
        let updated = try await group.updateGroupName(groupId: MockData.fridayId, name: "Renamed")
        #expect(updated.name == "Renamed")
        let reread = try await group.getGroups().first { $0.id == MockData.fridayId }
        #expect(reread?.name == "Renamed")
    }

    @Test func emptyGroupRepositoryHasNoActiveGroup() async throws {
        let group: GroupRepositoryProtocol = MockGroupRepository(groups: [], activeGroupId: nil)
        #expect(group.activeGroup == nil)
        #expect(try await group.getGroups().isEmpty)
    }

    // MARK: - Pint

    @Test func getMyPintsAllGroupsReturnsOnlyCurrentUsersPints() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let mine = try await pint.getMyPints(groupId: nil)
        #expect(mine.isEmpty == false)
        #expect(mine.allSatisfy { $0.userId == MockData.daveId })
    }

    @Test func getMyPintsFiltersByGroup() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let friday = try await pint.getMyPints(groupId: MockData.fridayId)
        #expect(friday.isEmpty == false)
        #expect(friday.allSatisfy { $0.groupId == MockData.fridayId && $0.userId == MockData.daveId })
    }

    @Test func getPintsForMemberReturnsThatMembersPints() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let emmas = try await pint.getPintsForMember(userId: MockData.emmaId, groupId: MockData.fridayId)
        #expect(emmas.isEmpty == false)
        #expect(emmas.allSatisfy { $0.userId == MockData.emmaId && $0.groupId == MockData.fridayId })
    }

    @Test func myPintsAreNewestFirst() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let mine = try await pint.getMyPints(groupId: nil)
        let dates = mine.map(\.loggedAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test func createPintAppearsInMyPints() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let created = try await pint.createPint(
            groupId: MockData.fridayId, photoData: Data([0xFF, 0xD8]),
            note: "Fresh one", drinkType: .ale, location: nil
        )
        let mine = try await pint.getMyPints(groupId: MockData.fridayId)
        #expect(mine.contains(created))
        #expect(mine.first == created)   // newest first
    }

    @Test func createPhotoOnlyPintIsValid() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let created = try await pint.createPint(
            groupId: MockData.fridayId, photoData: Data([0xFF, 0xD8]),
            note: nil, drinkType: nil, location: nil
        )
        #expect(created.note == nil)
        #expect(created.drinkType == nil)
    }

    @Test func editPintUpdatesNoteAndDrinkType() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let created = try await pint.createPint(
            groupId: MockData.fridayId, photoData: Data(), note: "old", drinkType: .beer, location: nil
        )
        let edited = try await pint.editPint(pintId: created.id, note: "new", drinkType: .stout)
        #expect(edited.note == "new")
        #expect(edited.drinkType == .stout)
    }

    @Test func deleteRecentPintSucceeds() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        // A freshly created pint is logged at MockData.now — inside the 24h window.
        let created = try await pint.createPint(
            groupId: MockData.fridayId, photoData: Data(), note: nil, drinkType: nil, location: nil
        )
        try await pint.deletePint(pintId: created.id)
        let mine = try await pint.getMyPints(groupId: MockData.fridayId)
        #expect(mine.contains(created) == false)
    }

    @Test func deleteOldPintThrowsForbidden() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        // Dave's Friday Club pint from 3 days ago — outside the 24h window.
        let mine = try await pint.getMyPints(groupId: MockData.fridayId)
        let old = mine.first { MockData.now.timeIntervalSince($0.loggedAt) > 24 * 3600 }!
        await #expect(throws: APIError.forbidden) {
            try await pint.deletePint(pintId: old.id)
        }
    }

    @Test func pendingPintsSeedOneOfEachStatus() async throws {
        // The mock seeds the offline queue (Task 17) with one still-uploading and
        // one failed pint so My Pints can exercise both badge states.
        let pint: PintRepositoryProtocol = MockPintRepository()
        #expect(pint.pendingPints.contains { $0.status == .pending })
        #expect(pint.pendingPints.contains { $0.status == .failed })
    }

    @Test func retryFlipsFailedPintBackToPending() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let failed = pint.pendingPints.first { $0.status == .failed }!
        try await pint.retryPint(pintId: failed.id)
        #expect(pint.pendingPints.first { $0.id == failed.id }?.status == .pending)
    }

    @Test func discardRemovesFromTheQueue() async throws {
        let pint: PintRepositoryProtocol = MockPintRepository()
        let some = pint.pendingPints.first!
        try await pint.discardPint(pintId: some.id)
        #expect(pint.pendingPints.contains { $0.id == some.id } == false)
    }

    // MARK: - Leaderboard

    @Test func allTimeLeaderboardHasNoDeltas() async throws {
        let board: LeaderboardRepositoryProtocol = MockLeaderboardRepository()
        let entries = try await board.getLeaderboard(groupId: MockData.fridayId, period: .allTime)
        #expect(entries.isEmpty == false)
        #expect(entries.allSatisfy { $0.rankDelta == nil })
    }

    @Test func weeklyLeaderboardCarriesDeltasForActiveMembers() async throws {
        let board: LeaderboardRepositoryProtocol = MockLeaderboardRepository()
        let entries = try await board.getLeaderboard(groupId: MockData.fridayId, period: .thisWeek)
        // At least one active, non-top member has a non-nil delta.
        #expect(entries.contains { !$0.isFormerMember && $0.rank > 1 && $0.rankDelta != nil })
    }

    @Test func leaderboardHasCrownTieAtRankOne() async throws {
        let board: LeaderboardRepositoryProtocol = MockLeaderboardRepository()
        let entries = try await board.getLeaderboard(groupId: MockData.fridayId, period: .allTime)
        #expect(entries.filter { $0.rank == 1 }.count == 2)   // two crowns
    }

    @Test func leaderboardSeparatesFormerMembers() async throws {
        let board: LeaderboardRepositoryProtocol = MockLeaderboardRepository()
        let entries = try await board.getLeaderboard(groupId: MockData.fridayId, period: .allTime)
        let formers = entries.filter(\.isFormerMember)
        #expect(formers.isEmpty == false)
        // Former members are unranked and never carry a delta.
        #expect(formers.allSatisfy { $0.rank == 0 && $0.rankDelta == nil })
    }

    @Test func emptyLeaderboardForUnknownGroup() async throws {
        let board: LeaderboardRepositoryProtocol = MockLeaderboardRepository()
        #expect(try await board.getLeaderboard(groupId: UUID(), period: .allTime).isEmpty)
    }

    // MARK: - Map

    /// A box covering central London — contains all the located fixture pints.
    private let londonSW = Coordinate(latitude: 51.40, longitude: -0.30)
    private let londonNE = Coordinate(latitude: 51.60, longitude: 0.05)

    @Test func mapReturnsGroupPintsInsideBox() async throws {
        let map: MapRepositoryProtocol = MockMapRepository()
        let pins = try await map.getPintsInBoundingBox(
            groupId: MockData.fridayId, scope: .group,
            southWest: londonSW, northEast: londonNE
        )
        #expect(pins.isEmpty == false)
        #expect(pins.allSatisfy { $0.groupId == MockData.fridayId })
    }

    @Test func mapNeverReturnsUnlocatedPints() async throws {
        let map: MapRepositoryProtocol = MockMapRepository()
        let pins = try await map.getPintsInBoundingBox(
            groupId: MockData.fridayId, scope: .group,
            southWest: londonSW, northEast: londonNE
        )
        #expect(pins.allSatisfy { $0.location != nil })
    }

    @Test func mapPersonalScopeFiltersToCurrentUser() async throws {
        let map: MapRepositoryProtocol = MockMapRepository()
        let pins = try await map.getPintsInBoundingBox(
            groupId: MockData.fridayId, scope: .personal,
            southWest: londonSW, northEast: londonNE
        )
        #expect(pins.isEmpty == false)
        #expect(pins.allSatisfy { $0.userId == MockData.daveId })
    }

    @Test func mapExcludesPintsOutsideBox() async throws {
        let map: MapRepositoryProtocol = MockMapRepository()
        // A tiny box in the ocean off West Africa — contains nothing.
        let pins = try await map.getPintsInBoundingBox(
            groupId: MockData.fridayId, scope: .group,
            southWest: Coordinate(latitude: 0, longitude: 0),
            northEast: Coordinate(latitude: 1, longitude: 1)
        )
        #expect(pins.isEmpty)
    }
}
