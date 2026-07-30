//
//  CameraModel.swift
//  PintKing
//
//  The @Observable owner of the camera capture session (l3-ios-app.md §5). It
//  configures an AVCaptureSession with the rear camera + an AVCapturePhotoOutput,
//  starts/stops the session, and on `capturePhoto()` runs the capture through
//  `PhotoProcessor` to publish a JPEG (or a typed error) for the UI to observe.
//
//  This is the hardware-bound half of the camera stack: the session needs a real
//  device, so it isn't unit-tested — the testable processing logic lives in
//  `PhotoProcessor` (see PhotoProcessorTests). The SwiftUI camera view and live
//  preview layer arrive in Task 12; this task builds the model they'll drive.
//
//  Threading note: AVFoundation's configure/start/stop are blocking calls that
//  must not run on the main thread, so they're dispatched to a private serial
//  `sessionQueue` as `nonisolated` work. The observable state the UI watches
//  (`capturedPhoto`, `captureError`, `isSessionRunning`) is only ever mutated
//  back on the main actor via `Task { @MainActor in … }`, keeping SwiftUI
//  observation safe. The `session`/`photoOutput` objects are their own internal
//  serialisation point, so touching them from the queue is fine.
//

import Foundation
import AVFoundation

@MainActor
@Observable
final class CameraModel: NSObject {

    /// The processed JPEG from the most recent successful capture, ready to hand
    /// to the post-capture sheet (Task 13). Nil until the first capture.
    private(set) var capturedPhoto: Data?

    /// Set when a capture fails — either AVFoundation reported an error or the
    /// photo was still too large after compression. The view shows this and stays
    /// on the camera so the user can retake.
    private(set) var captureError: CameraError?

    /// Whether the session is currently running (drives the preview lifecycle).
    private(set) var isSessionRunning = false

    /// The session the preview layer (Task 12) will attach to. Owned here.
    /// `nonisolated` so the session queue can touch it without hopping actors —
    /// AVCaptureSession serialises its own access.
    nonisolated let session = AVCaptureSession()

    nonisolated private let photoOutput = AVCapturePhotoOutput()

    /// Serial queue for the blocking configure/start/stop calls — never the main
    /// thread (AVFoundation explicitly warns against blocking it).
    nonisolated private let sessionQueue = DispatchQueue(label: "com.pintking.camera.session")

    // MARK: - Session lifecycle

    /// Build the capture graph: rear camera input → photo output, then start the
    /// session. Safe to call once when the camera view appears; the blocking work
    /// runs off the main actor. On failure it publishes `.configurationFailed`
    /// and leaves the session stopped.
    func configure() {
        sessionQueue.async { [session, photoOutput] in
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: .back
                ),
                let input = try? AVCaptureDeviceInput(device: camera),
                session.canAddInput(input),
                session.canAddOutput(photoOutput)
            else {
                session.commitConfiguration()
                Task { @MainActor [weak self] in self?.captureError = .configurationFailed }
                return
            }

            session.addInput(input)
            session.addOutput(photoOutput)
            session.commitConfiguration()
        }
    }

    /// Start the capture session (no-op if already running). Blocking, so it runs
    /// on the session queue; publishes `isSessionRunning` back on the main actor.
    func start() {
        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
            Task { @MainActor [weak self] in self?.isSessionRunning = true }
        }
    }

    /// Stop the capture session — called when the camera modal is dismissed so we
    /// release the hardware.
    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor [weak self] in self?.isSessionRunning = false }
        }
    }

    // MARK: - Capture

    /// Trigger a still capture. The result arrives asynchronously on the
    /// AVCapturePhotoCaptureDelegate callback below.
    func capturePhoto() {
        captureError = nil
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        // Pull the container bytes off the delegate thread, then hop to the main
        // actor to process and publish (PhotoProcessor is pure/thread-agnostic,
        // but the observable state it feeds must be touched on the main actor).
        let raw = photo.fileDataRepresentation()
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard error == nil, let raw else {
                self.captureError = .captureFailed
                return
            }
            do {
                self.capturedPhoto = try PhotoProcessor.process(raw)
            } catch {
                self.captureError = .photoTooLarge
            }
        }
    }
}

/// Why a capture or its setup failed, in UI terms.
enum CameraError: Error, Equatable, Sendable {
    /// The capture session couldn't be built (no camera, or access denied).
    case configurationFailed
    /// AVFoundation reported an error, or handed back no image data.
    case captureFailed
    /// The photo was still over the size cap after maximum compression.
    case photoTooLarge
}
