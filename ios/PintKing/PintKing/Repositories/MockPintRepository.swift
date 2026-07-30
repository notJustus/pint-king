//
//  MockPintRepository.swift
//  PintKing
//
//  In-memory pint store. Holds a mutable copy of the fixture pints so create /
//  edit / delete persist for the session. `createPint` appends a confirmed pint.
//  A seeded `pendingPints` queue (one pending, one failed) lets My Pints (Task 17)
//  exercise both badge states and the retry / discard actions; the real offline
//  queue mechanics land with Task 29. The 24h delete window is evaluated against
//  an injected clock (defaulting to `MockData.now`) so the fixtures behave
//  deterministically in tests.
//

import Foundation

@MainActor
@Observable
final class MockPintRepository: PintRepositoryProtocol {
    private var pints: [PintLog]
    private(set) var pendingPints: [PendingPint]

    private let currentUserId: UUID

    /// The "now" used for the 24h delete window. Defaults to `MockData.now` so the
    /// static fixtures (dated relative to it) behave deterministically; tests can
    /// pass a different clock to move a pint in or out of the window.
    private let now: Date

    init(
        pints: [PintLog] = MockData.pints,
        pending: [PendingPint] = MockData.pendingPints,
        currentUserId: UUID = MockData.currentUser.id,
        now: Date = MockData.now
    ) {
        // Newest first — the order the history screens display.
        self.pints = pints.sorted { $0.loggedAt > $1.loggedAt }
        self.pendingPints = pending
        self.currentUserId = currentUserId
        self.now = now
    }

    func createPint(
        groupId: UUID,
        photoData: Data,
        note: String?,
        drinkType: DrinkType?,
        location: Coordinate?
    ) async throws -> PintLog {
        let pint = PintLog(
            id: UUID(), userId: currentUserId, groupId: groupId,
            photoUrl: "pints/\(currentUserId)/\(groupId)/\(UUID()).jpg",
            note: note, drinkType: drinkType, location: location,
            loggedAt: MockData.now
        )
        pints.insert(pint, at: 0)   // newest first
        return pint
    }

    func getMyPints(groupId: UUID?) async throws -> [PintLog] {
        pints.filter { pint in
            pint.userId == currentUserId && (groupId == nil || pint.groupId == groupId)
        }
    }

    func getPintsForMember(userId: UUID, groupId: UUID) async throws -> [PintLog] {
        pints.filter { $0.userId == userId && $0.groupId == groupId }
    }

    @discardableResult
    func editPint(pintId: UUID, note: String?, drinkType: DrinkType?) async throws -> PintLog {
        guard let index = pints.firstIndex(where: { $0.id == pintId }) else {
            throw APIError.notFound
        }
        let p = pints[index]
        let updated = PintLog(
            id: p.id, userId: p.userId, groupId: p.groupId, photoUrl: p.photoUrl,
            note: note, drinkType: drinkType, location: p.location, loggedAt: p.loggedAt
        )
        pints[index] = updated
        return updated
    }

    func deletePint(pintId: UUID) async throws {
        guard let pint = pints.first(where: { $0.id == pintId }) else {
            throw APIError.notFound
        }
        // 24h window (Property 19). Outside it, the API rejects with 403.
        let age = now.timeIntervalSince(pint.loggedAt)
        guard age <= 24 * 60 * 60 else {
            throw APIError.forbidden
        }
        pints.removeAll { $0.id == pintId }
    }

    func retryPint(pintId: UUID) async throws {
        guard let index = pendingPints.firstIndex(where: { $0.id == pintId }) else {
            throw APIError.notFound
        }
        // Re-queue: a retried pint goes back to "pending". The actual upload
        // attempt lands with the offline queue (Task 29).
        pendingPints[index] = PendingPint(pint: pendingPints[index].pint, status: .pending)
    }

    func discardPint(pintId: UUID) async throws {
        pendingPints.removeAll { $0.id == pintId }
    }
}
