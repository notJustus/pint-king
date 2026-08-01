//
//  PintQueueStore.swift
//  PintKing
//
//  Where queued pints live between the shutter and the server. One directory,
//  two files per pint:
//
//      <directory>/<id>.jpg     the captured photo
//      <directory>/<id>.json    the QueuedPint metadata
//
//  A file per pint rather than one index file, so writing an attempt count is an
//  atomic write of one small file instead of a rewrite of the whole queue — a
//  crash mid-write can lose at most the record being touched.
//
//  **The photo is written first and the JSON second.** That ordering makes the
//  JSON the commit point: a record that exists is always uploadable, and an
//  interrupted save leaves an orphan photo rather than a metadata row pointing at
//  a file that isn't there. This is the same "store the blob, then the row"
//  ordering the API uses for S3 (ADR-0001).
//

import Foundation

struct PintQueueStore: Sendable {

    enum StoreError: Error, Equatable {
        /// The photo file for a queued pint is missing or unreadable.
        case photoUnavailable(UUID)
    }

    private let directory: URL

    /// A queued pint is *not* wire format — it never leaves the device, and
    /// nothing on the server ever reads it. So it deliberately does not use
    /// `JSONCoding`, whose `.iso8601` date strategy is second-resolution: a
    /// `capturedAt` written through it comes back rounded, and the record no
    /// longer equals what was saved. Foundation's default `Date` strategy is a
    /// `Double`, which round-trips exactly.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Defaults to Application Support, which is for data the app manages on the
    /// user's behalf and that the user does not browse — as opposed to Caches,
    /// which the system may evict. A queued pint is unrecoverable if evicted:
    /// the photo exists nowhere else.
    init(directory: URL? = nil) throws {
        self.directory = try directory ?? Self.defaultDirectory()
        try Self.createDirectory(at: self.directory)
    }

    private static func defaultDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "PintQueue", directoryHint: .isDirectory)
    }

    private static func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        // Queued pints are device-local work in progress. Restoring a backup onto
        // a new device should not resurrect uploads whose 24h window expired long
        // ago — the same reasoning that makes the keychain items ThisDeviceOnly
        // (ADR-0105).
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Paths

    /// The photo's location on disk. This doubles as the `photoUrl` a queued pint
    /// presents to the UI, so the My Pints row has something to render.
    func photoURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).jpg")
    }

    private func metadataURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    // MARK: - Writing

    /// Enqueues a pint: photo first, then metadata (see the file header).
    func save(_ pint: QueuedPint, photoData: Data) throws {
        try photoData.write(to: photoURL(for: pint.id), options: .atomic)
        try update(pint)
    }

    /// Rewrites just the metadata — the attempt count, the status, the retry
    /// timestamp. The photo never changes once captured.
    func update(_ pint: QueuedPint) throws {
        let data = try Self.encoder.encode(pint)
        try data.write(to: metadataURL(for: pint.id), options: .atomic)
    }

    func delete(id: UUID) throws {
        // Metadata first: with it gone the pint is out of the queue even if the
        // photo delete fails, and a stray photo is swept by the next `load()`.
        try? FileManager.default.removeItem(at: metadataURL(for: id))
        try? FileManager.default.removeItem(at: photoURL(for: id))
    }

    // MARK: - Reading

    func photoData(for id: UUID) throws -> Data {
        guard let data = try? Data(contentsOf: photoURL(for: id)) else {
            throw StoreError.photoUnavailable(id)
        }
        return data
    }

    /// Every queued pint on disk, newest capture first (the order My Pints shows
    /// them in).
    ///
    /// Non-throwing on purpose: this runs at launch, and a directory the app
    /// cannot read is a reason to start with an empty queue, not to fail to
    /// start. It is also the queue's only sweep — a record whose JSON no longer
    /// decodes, or whose photo is gone, can never be uploaded, so both are
    /// deleted here rather than left to accumulate (a queued photo is up to 10 MB).
    func load() -> [QueuedPint] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        var pints: [QueuedPint] = []
        var known: Set<UUID> = []

        for url in contents where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let pint = try? Self.decoder.decode(QueuedPint.self, from: data),
                  FileManager.default.fileExists(atPath: photoURL(for: pint.id).path) else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            pints.append(pint)
            known.insert(pint.id)
        }

        // Photos with no surviving metadata: an interrupted save, or the tail of
        // a delete that only got halfway.
        for url in contents where url.pathExtension == "jpg" {
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            if id == nil || !known.contains(id!) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        return pints.sorted { $0.capturedAt > $1.capturedAt }
    }
}
