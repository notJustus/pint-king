//
//  PintUploadQueue.swift
//  PintKing
//
//  The offline queue: captured pints that the server has not accepted yet, and
//  the policy for getting them there. Pint creation is the only thing the app
//  queues (l3-ios-app.md §8, ADR-0023) — everything else needs connectivity and
//  says so.
//
//  It owns three things and nothing else:
//
//    1. the in-memory mirror of what is on disk (`queued`, observable, so My
//       Pints re-renders when a status changes);
//    2. *when* to attempt an upload — on demand, and on the offline → online edge;
//    3. *when to stop trying* — 3 rejected attempts, or 24h in the queue.
//
//  Storage, transport, and connectivity are all injected, which is what lets the
//  policy be tested without a network, a disk of consequence, or a device.
//
//  The three members a `PintRepositoryProtocol` conformer needs — `pendingPints`,
//  `retryPint`, `discardPint` — are spelled exactly as the protocol spells them,
//  so the real repository forwards them verbatim when it lands.
//

import Foundation

@MainActor
@Observable
final class PintUploadQueue {

    /// Rejections tolerated before a pint is marked failed (l3-ios-app.md §8:
    /// "3 retries over 24 hours").
    static let maxAttempts = 3

    /// How long a pint may sit in the queue before it is given up on, measured
    /// from `queuedAt`. This is the backstop for the case attempts alone can't
    /// catch: a device that is simply never online.
    static let giveUpAfter: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private let store: PintQueueStore
    @ObservationIgnored private let uploader: PintUploading
    @ObservationIgnored private let monitor: NetworkMonitoring

    /// Injected clock, so the 24h window is exercisable in a test that finishes
    /// in milliseconds — the same trick `MockPintRepository` uses for the delete
    /// window.
    @ObservationIgnored private let now: @MainActor () -> Date

    /// The queue, newest capture first. Seeded from disk at init: this is the
    /// whole of "pints survive app restart".
    private(set) var queued: [QueuedPint]

    /// Guards against two overlapping passes — a manual `processQueue()` racing
    /// the one connectivity restoration kicked off, both uploading the same pint.
    @ObservationIgnored private var isProcessing = false

    init(
        store: PintQueueStore,
        uploader: PintUploading,
        monitor: NetworkMonitoring,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.store = store
        self.uploader = uploader
        self.monitor = monitor
        self.now = now
        self.queued = store.load()

        monitor.onConnectionRestored = { [weak self] in
            Task { await self?.processQueue() }
        }
    }

    // MARK: - What the UI sees

    /// The queue as `PintRepositoryProtocol.pendingPints`. Each row's `photoUrl`
    /// is the local file, so My Pints can render a pint that exists nowhere else
    /// yet.
    var pendingPints: [PendingPint] {
        queued.map { $0.asPendingPint(photoUrl: store.photoURL(for: $0.id).absoluteString) }
    }

    // MARK: - Enqueueing

    /// Saves a captured pint for later upload and returns it in the shape the
    /// caller would have got from the server, so a pint logged offline still
    /// appears immediately.
    ///
    /// This does *not* attempt an upload. The caller reaches here only after its
    /// own attempt failed (or after deciding not to try), so trying again in the
    /// same breath would be a guaranteed second failure.
    @discardableResult
    func enqueue(
        userId: UUID,
        groupId: UUID,
        photoData: Data,
        note: String?,
        drinkType: DrinkType?,
        location: Coordinate?
    ) throws -> PintLog {
        let capturedAt = now()
        let pint = QueuedPint(
            id: UUID(),
            userId: userId,
            groupId: groupId,
            note: note,
            drinkType: drinkType,
            location: location,
            capturedAt: capturedAt,
            queuedAt: capturedAt,
            attempts: 0,
            status: .pending
        )
        try store.save(pint, photoData: photoData)
        queued.insert(pint, at: 0)
        return pint.asPintLog(photoUrl: store.photoURL(for: pint.id).absoluteString)
    }

    // MARK: - Draining

    /// Attempts every pending pint, oldest first. Call it when the app comes to
    /// the foreground; connectivity returning calls it on its own.
    func processQueue() async {
        guard !isProcessing, monitor.isConnected else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Oldest queued first: the pint that has been waiting longest is also the
        // one closest to its 24h deadline.
        let batch = queued
            .filter { $0.status == .pending }
            .sorted { $0.queuedAt < $1.queuedAt }

        for pint in batch {
            // Re-read: an earlier iteration (or a discard) may have moved on.
            guard let current = queued.first(where: { $0.id == pint.id }) else { continue }

            if hasExpired(current) {
                fail(current)
                continue
            }

            guard let photoData = try? store.photoData(for: current.id) else {
                // The photo is the one thing that cannot be reconstructed, so a
                // record without it is not failed, it is void. `load()` sweeps
                // these at launch; this catches the same case mid-session.
                remove(current.id)
                continue
            }

            do {
                _ = try await uploader.upload(current, photoData: photoData)
                remove(current.id)
            } catch APIError.networkUnavailable {
                // The request never left the device, so nothing about this pint
                // was rejected — it costs no attempt. Stop the pass: every
                // remaining pint would fail identically.
                return
            } catch {
                recordRejection(current)
            }
        }
    }

    /// `PintRepositoryProtocol.retryPint` — the My Pints "Retry" action on a
    /// failed row. Resets the attempt count *and* the 24h window, then drains:
    /// a Retry button that reported failure without trying would be a lie.
    func retryPint(pintId: UUID) async throws {
        guard var pint = queued.first(where: { $0.id == pintId }) else {
            throw APIError.notFound
        }
        pint.attempts = 0
        pint.queuedAt = now()
        pint.status = .pending
        persist(pint)

        await processQueue()
    }

    /// `PintRepositoryProtocol.discardPint` — "Discard" on a queued row. Deletes
    /// the photo and the metadata; there is no server copy to worry about.
    func discardPint(pintId: UUID) throws {
        guard queued.contains(where: { $0.id == pintId }) else {
            throw APIError.notFound
        }
        try store.delete(id: pintId)
        queued.removeAll { $0.id == pintId }
    }

    // MARK: - Policy

    private func hasExpired(_ pint: QueuedPint) -> Bool {
        now().timeIntervalSince(pint.queuedAt) > Self.giveUpAfter
    }

    /// The server saw the request and said no. Spend an attempt; give up at the
    /// third.
    private func recordRejection(_ pint: QueuedPint) {
        var updated = pint
        updated.attempts += 1
        if updated.attempts >= Self.maxAttempts {
            updated.status = .failed
        }
        persist(updated)
    }

    private func fail(_ pint: QueuedPint) {
        var updated = pint
        updated.status = .failed
        persist(updated)
    }

    // MARK: - Mirror maintenance

    /// Memory and disk move together. The write is best-effort: the in-memory
    /// queue is what the UI reads, and the worst case of a lost metadata write is
    /// that a restart forgets one attempt — strictly safer than forgetting the
    /// pint.
    private func persist(_ pint: QueuedPint) {
        if let index = queued.firstIndex(where: { $0.id == pint.id }) {
            queued[index] = pint
        }
        try? store.update(pint)
    }

    private func remove(_ id: UUID) {
        try? store.delete(id: id)
        queued.removeAll { $0.id == id }
    }
}
