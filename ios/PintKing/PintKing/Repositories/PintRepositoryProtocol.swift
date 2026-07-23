//
//  PintRepositoryProtocol.swift
//  PintKing
//
//  Pint creation, history, edit, delete, and the offline queue (Task 29).
//  Creation takes raw photo data plus optional metadata; the repository decides
//  whether to upload now or queue (l3-ios-app.md §8). `pendingPints` surfaces the
//  queue to the My Pints screen.
//

import Foundation

@MainActor
protocol PintRepositoryProtocol: AnyObject {
    /// Log a pint: photo is mandatory, note / drinkType / location optional
    /// (a photo-only pint is valid — Task 13). Associated with the current user
    /// and the given group. Returns the created log.
    func createPint(
        groupId: UUID,
        photoData: Data,
        note: String?,
        drinkType: DrinkType?,
        location: Coordinate?
    ) async throws -> PintLog

    /// The current user's own pints. `groupId == nil` means all groups
    /// (My Pints "All Groups" filter).
    func getMyPints(groupId: UUID?) async throws -> [PintLog]

    /// A specific member's pints within a group (Member Pint History, Task 10).
    func getPintsForMember(userId: UUID, groupId: UUID) async throws -> [PintLog]

    /// Edit a pint's note and/or drink type. Returns the updated log.
    @discardableResult
    func editPint(pintId: UUID, note: String?, drinkType: DrinkType?) async throws -> PintLog

    /// Delete a pint. Rejected (throws) outside the 24h window (Property 19).
    func deletePint(pintId: UUID) async throws

    /// Pints saved locally and not yet confirmed by the server. Shown with a
    /// "pending" / "failed" badge in My Pints; never on the leaderboard or map.
    var pendingPints: [PintLog] { get }
}
