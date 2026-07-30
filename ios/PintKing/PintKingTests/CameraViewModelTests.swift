//
//  CameraViewModelTests.swift
//  PintKingTests
//
//  Task 12: camera screen logic. The AVCaptureSession preview and real capture
//  need a physical device, so those are verified on-device — here we drive the
//  view model's *decisions* against a MockCameraModel + MockCameraPermission:
//  granted → show the camera and start the session; denied → show the explanation
//  and never start; the shutter forwards to capture; disappear stops the session.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct CameraViewModelTests {

    private func make(
        status: CameraPermissionStatus,
        requestOutcome: CameraPermissionStatus = .granted
    ) -> (CameraViewModel, MockCameraModel, MockCameraPermission) {
        let camera = MockCameraModel()
        let permission = MockCameraPermission(status: status, requestOutcome: requestOutcome)
        let vm = CameraViewModel(camera: camera, permission: permission)
        return (vm, camera, permission)
    }

    // MARK: - Permission gating

    @Test func startsInCheckingPhase() {
        let (vm, camera, _) = make(status: .notDetermined)
        #expect(vm.phase == .checking)
        // Nothing touches the hardware until onAppear resolves permission.
        #expect(camera.configureCount == 0)
        #expect(camera.startCount == 0)
    }

    @Test func grantedPromptShowsCameraAndStartsSession() async {
        let (vm, camera, permission) = make(status: .notDetermined, requestOutcome: .granted)
        await vm.onAppear()
        #expect(vm.phase == .camera)
        #expect(permission.requestCount == 1)
        #expect(camera.configureCount == 1)
        #expect(camera.startCount == 1)
    }

    @Test func deniedPromptShowsExplanationAndNeverStarts() async {
        let (vm, camera, _) = make(status: .notDetermined, requestOutcome: .denied)
        await vm.onAppear()
        #expect(vm.phase == .denied)
        #expect(camera.configureCount == 0)
        #expect(camera.startCount == 0)
    }

    @Test func alreadyGrantedShowsCameraWithoutReprompt() async {
        // request() still returns the standing status, but it doesn't re-prompt
        // the user — MockCameraPermission only resolves from `.notDetermined`.
        let (vm, camera, permission) = make(status: .granted)
        await vm.onAppear()
        #expect(vm.phase == .camera)
        #expect(permission.requestCount == 1)
        #expect(camera.startCount == 1)
    }

    @Test func alreadyDeniedShowsExplanation() async {
        let (vm, camera, _) = make(status: .denied)
        await vm.onAppear()
        #expect(vm.phase == .denied)
        #expect(camera.startCount == 0)
    }

    // MARK: - Shutter + lifecycle

    @Test func shutterTapTriggersCapture() {
        let (vm, camera, _) = make(status: .granted)
        vm.capturePhoto()
        #expect(camera.captureCount == 1)
    }

    @Test func disappearStopsSession() {
        let (vm, camera, _) = make(status: .granted)
        vm.onDisappear()
        #expect(camera.stopCount == 1)
    }

    // MARK: - Passthrough outputs

    @Test func capturedPhotoAndErrorReadThroughFromCamera() {
        let (vm, camera, _) = make(status: .granted)
        #expect(vm.capturedPhoto == nil)
        #expect(vm.captureError == nil)

        camera.capturedPhoto = Data([0xFF, 0xD8])
        camera.captureError = .captureFailed
        #expect(vm.capturedPhoto == Data([0xFF, 0xD8]))
        #expect(vm.captureError == .captureFailed)
    }
}
