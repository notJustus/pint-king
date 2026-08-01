//
//  PintUploadQueueTests.swift
//  PintKingTests
//
//  Task 29: the queue's policy, driven through its three seams — a real store on
//  a temporary directory, a mock transport, and connectivity a test can flip.
//  The clock is injected too, so "24 hours later" costs nothing.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
final class PintUploadQueueTests {

    private let directory: URL
    private let store: PintQueueStore
    private let uploader = MockPintUploader()
    private let monitor = MockNetworkMonitor()

    /// The queue's "now", movable by a test.
    private var clock = Date(timeIntervalSince1970: 1_700_000_000)

    private let photo = Data("jpeg-bytes".utf8)

    init() throws {
        directory = URL.temporaryDirectory.appending(path: "PintQueueTests-\(UUID().uuidString)")
        store = try PintQueueStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func makeQueue() -> PintUploadQueue {
        PintUploadQueue(store: store, uploader: uploader, monitor: monitor, now: { self.clock })
    }

    @discardableResult
    private func enqueue(on queue: PintUploadQueue, note: String? = "A pint") throws -> PintLog {
        try queue.enqueue(
            userId: UUID(), groupId: UUID(), photoData: photo,
            note: note, drinkType: .stout,
            location: Coordinate(latitude: 51.5, longitude: -0.12)
        )
    }

    private func advance(hours: Double) {
        clock = clock.addingTimeInterval(hours * 60 * 60)
    }

    // MARK: - Enqueueing while offline

    @Test func aPintLoggedOfflineAppearsAsPending() throws {
        monitor.isConnected = false
        let queue = makeQueue()

        try enqueue(on: queue)

        #expect(queue.pendingPints.count == 1)
        #expect(queue.pendingPints.first?.status == .pending)
    }

    @Test func enqueueDoesNotAttemptAnUpload() throws {
        let queue = makeQueue()

        try enqueue(on: queue)

        // The caller only reaches enqueue after its own attempt failed.
        #expect(uploader.attemptCount == 0)
    }

    @Test func aQueuedPintCarriesItsMetadataAndLocalPhotoURL() throws {
        let queue = makeQueue()

        let log = try enqueue(on: queue, note: "Bad signal in the basement.")

        #expect(log.note == "Bad signal in the basement.")
        #expect(log.drinkType == .stout)
        #expect(log.location == Coordinate(latitude: 51.5, longitude: -0.12))
        // The row renders from disk until the server has a URL of its own.
        #expect(log.photoUrl == store.photoURL(for: log.id).absoluteString)
        #expect(try Data(contentsOf: store.photoURL(for: log.id)) == photo)
    }

    @Test func aQueuedPintSurvivesARestart() throws {
        monitor.isConnected = false
        let log = try enqueue(on: makeQueue())

        // A second queue over the same directory is what the next launch builds.
        let relaunched = makeQueue()

        #expect(relaunched.pendingPints.map(\.id) == [log.id])
    }

    // MARK: - Draining

    @Test func aSuccessfulUploadLeavesTheQueue() async throws {
        let queue = makeQueue()
        let log = try enqueue(on: queue)

        await queue.processQueue()

        #expect(uploader.attempted == [log.id])
        #expect(queue.pendingPints.isEmpty)
        // And it is gone from disk, not just from memory.
        #expect(makeQueue().pendingPints.isEmpty)
    }

    @Test func nothingIsAttemptedWhileOffline() async throws {
        monitor.isConnected = false
        let queue = makeQueue()
        try enqueue(on: queue)

        await queue.processQueue()

        #expect(uploader.attemptCount == 0)
        #expect(queue.pendingPints.count == 1)
    }

    @Test func connectivityReturningDrainsTheQueue() async throws {
        monitor.isConnected = false
        let queue = makeQueue()
        try enqueue(on: queue)

        monitor.isConnected = true
        // The restoration handler starts a Task; let it run.
        await Task.yield()
        await queue.processQueue()

        #expect(queue.pendingPints.isEmpty)
    }

    @Test func theOldestQueuedPintIsAttemptedFirst() async throws {
        let queue = makeQueue()
        let first = try enqueue(on: queue)
        advance(hours: 1)
        let second = try enqueue(on: queue)

        await queue.processQueue()

        #expect(uploader.attempted == [first.id, second.id])
    }

    // MARK: - Failure policy

    @Test func aRejectionCostsOneAttemptButKeepsThePintPending() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        try enqueue(on: queue)

        await queue.processQueue()

        #expect(queue.queued.first?.attempts == 1)
        #expect(queue.pendingPints.first?.status == .pending)
    }

    @Test func threeRejectionsMarkThePintFailed() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        try enqueue(on: queue)

        for _ in 0..<3 { await queue.processQueue() }

        #expect(uploader.attemptCount == 3)
        #expect(queue.pendingPints.first?.status == .failed)
    }

    @Test func aFailedPintIsNotAttemptedAgain() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        try enqueue(on: queue)
        for _ in 0..<3 { await queue.processQueue() }

        await queue.processQueue()

        #expect(uploader.attemptCount == 3)
    }

    @Test func attemptCountsSurviveARestart() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        try enqueue(on: queue)
        await queue.processQueue()

        // Two more attempts, but across relaunches — the third still gives up.
        await makeQueue().processQueue()
        let third = makeQueue()
        await third.processQueue()

        #expect(third.pendingPints.first?.status == .failed)
    }

    @Test func aTransportFailureCostsNoAttempt() async throws {
        // Connectivity died between the monitor's answer and the request.
        uploader.error = APIError.networkUnavailable
        let queue = makeQueue()
        try enqueue(on: queue)

        await queue.processQueue()

        #expect(uploader.attemptCount == 1)   // it was tried…
        #expect(queue.queued.first?.attempts == 0)   // …but nothing was rejected.
        #expect(queue.pendingPints.first?.status == .pending)
    }

    @Test func aTransportFailureStopsTheWholePass() async throws {
        uploader.error = APIError.networkUnavailable
        let queue = makeQueue()
        try enqueue(on: queue)
        advance(hours: 1)
        try enqueue(on: queue)

        await queue.processQueue()

        // The second pint would fail identically, so it is never tried.
        #expect(uploader.attemptCount == 1)
    }

    // MARK: - The 24h window

    @Test func aPintOlderThanTheWindowFailsWithoutBeingAttempted() async throws {
        monitor.isConnected = false
        let queue = makeQueue()
        try enqueue(on: queue)

        advance(hours: 25)
        monitor.isConnected = true
        await queue.processQueue()

        #expect(uploader.attemptCount == 0)
        #expect(queue.pendingPints.first?.status == .failed)
    }

    @Test func aPintInsideTheWindowIsStillAttempted() async throws {
        monitor.isConnected = false
        let queue = makeQueue()
        try enqueue(on: queue)

        advance(hours: 23)
        monitor.isConnected = true
        await queue.processQueue()

        #expect(queue.pendingPints.isEmpty)
    }

    // MARK: - Retry

    @Test func retryResetsTheAttemptCountAndUploads() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        let log = try enqueue(on: queue)
        for _ in 0..<3 { await queue.processQueue() }
        #expect(queue.pendingPints.first?.status == .failed)

        uploader.error = nil
        try await queue.retryPint(pintId: log.id)

        #expect(queue.pendingPints.isEmpty)
    }

    @Test func retryGivesAFreshTwentyFourHourWindow() async throws {
        uploader.error = APIError.serverError
        let queue = makeQueue()
        let log = try enqueue(on: queue)
        await queue.processQueue()

        // Two days later the original window is long gone.
        advance(hours: 48)
        uploader.error = nil
        try await queue.retryPint(pintId: log.id)

        // Retry that reported failure without trying would be a lie.
        #expect(queue.pendingPints.isEmpty)
    }

    @Test func retryingAnUnknownPintThrows() async {
        let queue = makeQueue()

        await #expect(throws: APIError.notFound) {
            try await queue.retryPint(pintId: UUID())
        }
    }

    // MARK: - Discard

    @Test func discardRemovesThePintFromDiskAndMemory() async throws {
        let queue = makeQueue()
        let log = try enqueue(on: queue)

        try queue.discardPint(pintId: log.id)

        #expect(queue.pendingPints.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.photoURL(for: log.id).path))
        #expect(makeQueue().pendingPints.isEmpty)
    }

    @Test func discardingAnUnknownPintThrows() {
        let queue = makeQueue()

        #expect(throws: APIError.notFound) {
            try queue.discardPint(pintId: UUID())
        }
    }

    @Test func discardDoesNotTouchTheOtherQueuedPints() async throws {
        let queue = makeQueue()
        let keep = try enqueue(on: queue)
        advance(hours: 1)
        let drop = try enqueue(on: queue)

        try queue.discardPint(pintId: drop.id)

        #expect(queue.pendingPints.map(\.id) == [keep.id])
    }
}
