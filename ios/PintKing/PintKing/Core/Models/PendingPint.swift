//
//  PendingPint.swift
//  PintKing
//
//  A pint held in the local offline queue: the `PintLog` plus its current upload
//  status. Surfaced only by `PintRepository.pendingPints` and shown only in My
//  Pints (Task 17) with a "pending" / "failed" badge — never on the leaderboard
//  or map (ADR-0025). The queue mechanics that produce these (background upload,
//  retry, permanent failure) land with the offline queue in Task 29; this type is
//  just the shape the UI renders.
//

import Foundation

struct PendingPint: Identifiable, Equatable, Sendable {
    /// Where a queued pint is in its upload lifecycle. `pending` = still uploading
    /// (or waiting for connectivity); `failed` = gave up after retries, so the row
    /// offers retry / discard.
    ///
    /// `Codable` with explicit raw values because this is persisted as part of
    /// `QueuedPint` (Task 29) — the string on disk should stay readable and
    /// stable if a future case is added.
    enum Status: String, Codable, Sendable, Equatable {
        case pending
        case failed
    }

    let pint: PintLog
    let status: Status

    /// Identity follows the wrapped pint, so a queued pint keeps its identity as
    /// it moves failed → pending on retry.
    var id: UUID { pint.id }
}
