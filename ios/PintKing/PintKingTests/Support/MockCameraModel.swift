//
//  MockCameraModel.swift
//  PintKingTests
//
//  A hardware-free CameraControlling for driving CameraViewModel in tests. It
//  owns a real (idle) AVCaptureSession only to satisfy the protocol — configure/
//  start/stop/capturePhoto never touch it, they just tally calls so tests can
//  assert the view model's orchestration (start only after a granted prompt,
//  shutter → capture, disappear → stop).
//

import AVFoundation
@testable import PintKing

@MainActor
@Observable
final class MockCameraModel: CameraControlling {
    let session = AVCaptureSession()
    var capturedPhoto: Data?
    var captureError: CameraError?

    private(set) var configureCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var captureCount = 0

    func configure() { configureCount += 1 }
    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func capturePhoto() { captureCount += 1 }
}
