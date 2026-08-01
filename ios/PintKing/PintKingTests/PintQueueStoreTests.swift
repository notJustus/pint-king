//
//  PintQueueStoreTests.swift
//  PintKingTests
//
//  Task 29: the real file system, not a fake — like the keychain tests, the risk
//  being covered *is* the I/O. Each suite instance gets a fresh temporary
//  directory and removes it in `deinit`, which is also a live demonstration of
//  the store being directory-scoped rather than a singleton.
//

import Foundation
import Testing
@testable import PintKing

final class PintQueueStoreTests {

    private let directory: URL
    private let store: PintQueueStore

    init() throws {
        directory = URL.temporaryDirectory.appending(path: "PintQueueTests-\(UUID().uuidString)")
        store = try PintQueueStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func makePint(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        attempts: Int = 0,
        status: PendingPint.Status = .pending
    ) -> QueuedPint {
        QueuedPint(
            id: id, userId: UUID(), groupId: UUID(),
            note: "A pint", drinkType: .stout,
            location: Coordinate(latitude: 51.5, longitude: -0.12),
            capturedAt: capturedAt, queuedAt: capturedAt,
            attempts: attempts, status: status
        )
    }

    private let photo = Data("jpeg-bytes".utf8)

    // MARK: - Round trip

    @Test func savedPintLoadsBackUnchanged() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)

        let loaded = try #require(store.load().first)
        #expect(loaded == pint)
    }

    @Test func savedPhotoLoadsBackUnchanged() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)

        #expect(try store.photoData(for: pint.id) == photo)
    }

    @Test func loadingAnEmptyQueueReturnsNothing() {
        #expect(store.load().isEmpty)
    }

    @Test func pintsLoadNewestCaptureFirst() throws {
        let older = makePint(capturedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makePint(capturedAt: Date(timeIntervalSince1970: 2_000))
        try store.save(older, photoData: photo)
        try store.save(newer, photoData: photo)

        #expect(store.load().map(\.id) == [newer.id, older.id])
    }

    // MARK: - Update

    @Test func updateRewritesMetadataOnly() throws {
        var pint = makePint()
        try store.save(pint, photoData: photo)

        pint.attempts = 2
        pint.status = .failed
        try store.update(pint)

        let loaded = try #require(store.load().first)
        #expect(loaded.attempts == 2)
        #expect(loaded.status == .failed)
        // The photo is untouched by a metadata write.
        #expect(try store.photoData(for: pint.id) == photo)
    }

    // MARK: - Delete

    @Test func deleteRemovesBothFiles() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)
        try store.delete(id: pint.id)

        #expect(store.load().isEmpty)
        #expect(throws: PintQueueStore.StoreError.photoUnavailable(pint.id)) {
            try self.store.photoData(for: pint.id)
        }
    }

    @Test func deletingAnUnknownPintIsHarmless() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)

        try store.delete(id: UUID())

        #expect(store.load().count == 1)
    }

    // MARK: - Sweeping

    @Test func metadataWithoutAPhotoIsDroppedAndDeleted() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)
        // Simulate the photo going missing under us.
        try FileManager.default.removeItem(at: store.photoURL(for: pint.id))

        #expect(store.load().isEmpty)
        // Swept, not merely skipped — a second load has nothing left to skip.
        let remaining = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(remaining.isEmpty)
    }

    @Test func aPhotoWithoutMetadataIsSweptAway() throws {
        // What an interrupted `save` leaves behind: photo written, JSON not.
        let orphan = directory.appending(path: "\(UUID().uuidString).jpg")
        try photo.write(to: orphan)

        #expect(store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: orphan.path))
    }

    @Test func undecodableMetadataIsSweptAway() throws {
        let id = UUID()
        try photo.write(to: store.photoURL(for: id))
        try Data("not json".utf8).write(to: directory.appending(path: "\(id.uuidString).json"))

        #expect(store.load().isEmpty)
        let remaining = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(remaining.isEmpty)
    }

    @Test func unrelatedFilesAreLeftAlone() throws {
        let stranger = directory.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: stranger)

        _ = store.load()

        #expect(FileManager.default.fileExists(atPath: stranger.path))
    }

    // MARK: - Persistence across instances

    @Test func aSecondStoreOverTheSameDirectorySeesTheQueue() throws {
        let pint = makePint()
        try store.save(pint, photoData: photo)

        // A fresh store is what the next app launch builds.
        let relaunched = try PintQueueStore(directory: directory)
        #expect(relaunched.load().map(\.id) == [pint.id])
    }
}
