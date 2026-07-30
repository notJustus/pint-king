//
//  CameraView.swift
//  PintKing
//
//  The full-screen camera modal: live preview with a large circular shutter and a
//  close button. It's a thin renderer over CameraViewModel — the view model owns
//  the permission gate and session lifecycle, so this file just branches on
//  `phase` and forwards taps. When access is denied it shows an explanation with a
//  deep-link into Settings. Live preview + real capture need a physical device
//  (the simulator has no camera), so this view's happy path is verified on-device;
//  the gating and shutter-triggers-capture logic are unit-tested on the view model.
//
//  Once a shot is captured (`capturedPhoto` becomes non-nil) the post-capture
//  sheet slides up over the preview to collect optional note/drink type; its Done
//  logs the pint and dismisses the whole camera modal (Task 13).
//

import SwiftUI

struct CameraView: View {
    @State private var model: CameraViewModel

    /// The just-captured photo, surfaced to drive the post-capture sheet. Held in
    /// local state (not read live off the model) so dismissing the sheet to retake
    /// clears it here without the sheet immediately re-presenting.
    @State private var pendingPhoto: CapturedPhoto?

    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol
    let onClose: () -> Void

    init(
        camera: any CameraControlling,
        permission: any CameraPermissionRequesting,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: CameraViewModel(camera: camera, permission: permission))
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .checking:
                ProgressView()
                    .tint(.white)
            case .camera:
                cameraContent
            case .denied:
                deniedContent
            }
        }
        .overlay(alignment: .topLeading) { closeButton }
        .task { await model.onAppear() }
        .onDisappear { model.onDisappear() }
        // A fresh capture opens the post-capture sheet.
        .onChange(of: model.capturedPhoto) { _, photo in
            if let photo { pendingPhoto = CapturedPhoto(data: photo) }
        }
        .sheet(item: $pendingPhoto) { photo in
            PostCaptureSheetView(
                photoData: photo.data,
                groupRepository: groupRepository,
                pintRepository: pintRepository,
                onDone: onClose   // logging a pint closes the whole camera modal
            )
        }
    }

    // MARK: - Camera (granted)

    private var cameraContent: some View {
        VStack {
            if let captureError = model.captureError {
                Text(message(for: captureError))
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 8))
                    .padding(.top, 60)
            }

            CameraPreviewView(session: model.session)
                .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) { shutterButton }
    }

    /// Large circular shutter — a white ring around a filled disc, the platform
    /// convention. Fills `model.capturePhoto()`, which the model routes to capture.
    private var shutterButton: some View {
        Button(action: { model.capturePhoto() }) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(.white)
                    .frame(width: 60, height: 60)
            }
        }
        .padding(.bottom, 40)
        .accessibilityLabel("Take photo")
    }

    // MARK: - Denied

    private var deniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
            Text("Camera Access Needed")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Pint King needs the camera to photograph your pint. Enable camera access in Settings to log a pint.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundStyle(.white)
                .padding()
        }
        .accessibilityLabel("Close camera")
    }

    private func message(for error: CameraError) -> String {
        switch error {
        case .configurationFailed:
            return "Couldn't start the camera. Close and try again."
        case .captureFailed:
            return "That shot didn't take. Try again."
        case .photoTooLarge:
            return "That photo was too large. Try another shot."
        }
    }
}

/// Wraps the captured JPEG in an `Identifiable` so it can drive `.sheet(item:)`.
/// A new capture gets a new identity, re-presenting the sheet even if the bytes
/// happen to match a prior shot.
private struct CapturedPhoto: Identifiable {
    let id = UUID()
    let data: Data
}
