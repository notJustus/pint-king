//
//  MockPintRepository.swift
//  PintKing
//
//  In-memory pint store. Holds a mutable copy of the fixture pints so create /
//  edit / delete persist for the session. `createPint` appends a confirmed pint
//  (the offline queue itself is Task 29 — `pendingPints` is exposed but stays
//  empty here). The 24h delete window is evaluated against `MockData.now` so the
//  fixtures behave deterministically.
//

import Foundation

@MainActor
@Observable
final class MockPintRepository: PintRepositoryProtocol {
    private var pints: [PintLog]
    private(set) var pendingPints: [PintLog] = []

    private let currentUserId: UUID

    init(pints: [PintLog] = MockData.pints, currentUserId: UUID = MockData.currentUser.id) {
        // Newest first — the order the history screens display.
        self.pints = pints.sorted { $0.loggedAt > $1.loggedAt }
        self.currentUserId = currentUserId
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
        let age = MockData.now.timeIntervalSince(pint.loggedAt)
        guard age <= 24 * 60 * 60 else {
            throw APIError.forbidden
        }
        pints.removeAll { $0.id == pintId }
    }
}
