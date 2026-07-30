//
//  AVCameraPermission.swift
//  PintKing
//
//  The real AVFoundation-backed CameraPermissionRequesting. Reads
//  AVCaptureDevice.authorizationStatus(for: .video) and, when undecided, calls
//  requestAccess(for:) — which already bridges its completion handler into
//  async/await, so no CheckedContinuation dance is needed (unlike CoreLocation).
//

import AVFoundation

@MainActor
final class AVCameraPermission: CameraPermissionRequesting {
    var status: CameraPermissionStatus {
        Self.map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func request() async -> CameraPermissionStatus {
        // Only `.notDetermined` shows the system prompt; any other status is a
        // standing decision we just report back.
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
            return status
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }

    private static func map(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        default: return .denied  // .denied and .restricted both mean "no access"
        }
    }
}
