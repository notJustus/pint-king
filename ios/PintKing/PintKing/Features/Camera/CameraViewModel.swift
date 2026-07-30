//
//  CameraViewModel.swift
//  PintKing
//
//  Orchestrates the camera screen: it owns the permission gate and the session
//  lifecycle, so CameraView stays a thin renderer. On appear it asks for camera
//  access, and only starts the session if that's granted; a denial flips the view
//  to an explanation screen with a Settings deep-link. The shutter forwards to the
//  camera's capture, and on disappear the session is stopped to release hardware.
//
//  Both collaborators are injected behind protocols (CameraPermissionRequesting,
//  CameraControlling), so this logic is unit-tested against mocks — the real
//  AVCaptureSession preview and capture are verified on-device (Task 12 note).
//

import Foundation
import AVFoundation

@MainActor
@Observable
final class CameraViewModel {
    /// What the screen should render. Starts `.checking` (a brief neutral state
    /// before the first permission answer) so we never flash the wrong UI.
    enum Phase: Equatable {
        case checking
        case camera
        case denied
    }

    private(set) var phase: Phase = .checking

    private let camera: any CameraControlling
    private let permission: any CameraPermissionRequesting

    init(
        camera: any CameraControlling,
        permission: any CameraPermissionRequesting
    ) {
        self.camera = camera
        self.permission = permission
    }

    /// The capture session the preview layer attaches to.
    var session: AVCaptureSession { camera.session }

    /// The processed JPEG from the latest capture, surfaced for the view (and,
    /// next task, the post-capture sheet).
    var capturedPhoto: Data? { camera.capturedPhoto }

    /// The most recent capture failure, for an inline retake message.
    var captureError: CameraError? { camera.captureError }

    /// Called when the camera screen appears. Requests access (or reads the
    /// standing decision), then either configures + starts the session or shows
    /// the denied explanation.
    func onAppear() async {
        let status = await permission.request()
        switch status {
        case .granted:
            phase = .camera
            camera.configure()
            camera.start()
        case .denied, .notDetermined:
            // `.notDetermined` shouldn't come back from request(), but if it does
            // we treat it as no-access rather than starting a session we can't use.
            phase = .denied
        }
    }

    /// Called when the screen disappears — release the capture hardware.
    func onDisappear() {
        camera.stop()
    }

    /// Shutter tap.
    func capturePhoto() {
        camera.capturePhoto()
    }
}
