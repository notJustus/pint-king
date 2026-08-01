//
//  MockPintUploader.swift
//  PintKingTests
//
//  A transport for PintUploadQueue that never touches the network. It records
//  every attempt (so a test can assert that being offline costs *no* attempt)
//  and can be told to fail — the distinction between `.networkUnavailable` and
//  anything else is the whole point, since only one of them spends a retry.
//

import Foundation
@testable import PintKing

@MainActor
final class MockPintUploader: PintUploading {

    /// Thrown by the next upload, if set. `nil` means success.
    var error: Error?

    /// Ids of every pint an upload was attempted for, in order.
    private(set) var attempted: [UUID] = []

    var attemptCount: Int { attempted.count }

    init(error: Error? = nil) {
        self.error = error
    }

    func upload(_ pint: QueuedPint, photoData: Data) async throws -> PintLog {
        attempted.append(pint.id)
        if let error { throw error }
        // The server assigns a new id and a real photo URL; the queue discards
        // the result either way, so the shape only has to be valid.
        return PintLog(
            id: UUID(), userId: pint.userId, groupId: pint.groupId,
            photoUrl: "pints/\(pint.userId)/\(pint.groupId)/\(UUID()).jpg",
            note: pint.note, drinkType: pint.drinkType, location: pint.location,
            loggedAt: Date()
        )
    }
}

/// Connectivity a test can flip. Setting `isConnected` from false to true fires
/// the restoration handler, exactly as `NWPathMonitor` crossing that edge does.
@MainActor
final class MockNetworkMonitor: NetworkMonitoring {

    var onConnectionRestored: (@MainActor () -> Void)?

    var isConnected: Bool {
        didSet {
            if isConnected && !oldValue { onConnectionRestored?() }
        }
    }

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}
