//
//  QueuedPint.swift
//  PintKing
//
//  A pint that has been captured but not yet accepted by the server: everything
//  needed to replay `POST /pints` later, plus the bookkeeping the retry policy
//  runs on. This is the *persisted* shape — it survives app restarts.
//
//  It is deliberately not a `PintLog`. A PintLog carries server-assigned facts
//  (its id, its S3 `photoUrl`, the `loggedAt` the server stamped) that a queued
//  pint does not have yet, so storing one would mean inventing them on disk.
//  `PendingPint` (the shape My Pints renders) is derived from this instead, with
//  the photo's local file URL standing in for the S3 one — see `asPendingPint`.
//

import Foundation

struct QueuedPint: Codable, Equatable, Identifiable, Sendable {

    /// Local identity, assigned at capture. The server will assign a different
    /// id when the upload succeeds; this one only ever names the local files and
    /// the row in My Pints.
    let id: UUID

    let userId: UUID

    /// The group this pint was logged into, recorded so the My Pints group
    /// filter can place the row. Note that `POST /pints` derives the group from
    /// the caller's *active* group and takes no group id — see ADR-0107.
    let groupId: UUID

    let note: String?
    let drinkType: DrinkType?
    let location: Coordinate?

    /// When the shutter fired. Displayed as the pint's timestamp while it is
    /// queued; the server will stamp its own `loggedAt` on acceptance.
    let capturedAt: Date

    /// When this pint last entered the queue — at capture, or at a user-initiated
    /// retry. The 24h give-up window is measured from here, not from `capturedAt`,
    /// so pressing Retry on a day-old failure actually gets a chance to run.
    var queuedAt: Date

    /// Upload attempts that reached the server and were rejected. Being offline
    /// costs nothing (ADR-0107).
    var attempts: Int

    var status: PendingPint.Status
}

extension QueuedPint {

    /// The queued pint as My Pints wants to see it. `photoUrl` is the local file
    /// URL of the captured JPEG — the row renders from disk until the server has
    /// somewhere of its own to point at.
    func asPintLog(photoUrl: String) -> PintLog {
        PintLog(
            id: id,
            userId: userId,
            groupId: groupId,
            photoUrl: photoUrl,
            note: note,
            drinkType: drinkType,
            location: location,
            loggedAt: capturedAt
        )
    }

    func asPendingPint(photoUrl: String) -> PendingPint {
        PendingPint(pint: asPintLog(photoUrl: photoUrl), status: status)
    }
}
