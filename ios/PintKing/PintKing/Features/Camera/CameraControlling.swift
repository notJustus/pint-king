//
//  CameraControlling.swift
//  PintKing
//
//  The slice of CameraModel that CameraViewModel drives: session lifecycle,
//  shutter, and the observable outputs the view watches. Pulling it behind a
//  protocol lets the view model be unit-tested against a fake (MockCameraModel)
//  without a real AVCaptureSession — the same split that keeps PhotoProcessor
//  testable while CameraModel's hardware path is verified on-device.
//
//  `session` is exposed as `AVCaptureSession` (not abstracted) because only the
//  UIViewRepresentable preview layer touches it, and that's device-only code
//  anyway — nothing in the tested path reads it.
//

import AVFoundation

@MainActor
protocol CameraControlling: AnyObject {
    /// The session the preview layer attaches to.
    var session: AVCaptureSession { get }

    /// The processed JPEG from the most recent successful capture (nil until one).
    var capturedPhoto: Data? { get }

    /// The most recent capture/setup failure, if any.
    var captureError: CameraError? { get }

    /// Build the capture graph and start the session.
    func configure()
    /// Start the session (no-op if running).
    func start()
    /// Stop the session — release the hardware when the modal is dismissed.
    func stop()
    /// Trigger a still capture; the result lands on `capturedPhoto`/`captureError`.
    func capturePhoto()
}

extension CameraModel: CameraControlling {}
