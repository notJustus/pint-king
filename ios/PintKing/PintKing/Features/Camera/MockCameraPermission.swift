//
//  MockCameraPermission.swift
//  PintKing
//
//  In-memory CameraPermissionRequesting for UI development and unit tests.
//  Reports a preset status and, when asked, resolves `.notDetermined` to a
//  configurable outcome — while counting requests so tests can assert the screen
//  prompts exactly once (and not again once the user has decided).
//

import Foundation

@MainActor
@Observable
final class MockCameraPermission: CameraPermissionRequesting {
    /// The standing status. `request()` returns this unchanged unless it's
    /// `.notDetermined`, in which case it resolves to `requestOutcome`.
    var status: CameraPermissionStatus

    /// What a prompt (from `.notDetermined`) resolves to.
    var requestOutcome: CameraPermissionStatus

    /// How many times `request()` has been called.
    private(set) var requestCount = 0

    init(
        status: CameraPermissionStatus = .notDetermined,
        requestOutcome: CameraPermissionStatus = .granted
    ) {
        self.status = status
        self.requestOutcome = requestOutcome
    }

    func request() async -> CameraPermissionStatus {
        requestCount += 1
        if status == .notDetermined {
            status = requestOutcome
        }
        return status
    }
}
