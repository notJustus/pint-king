//
//  CameraPermission.swift
//  PintKing
//
//  A tiny abstraction over the one thing the camera screen needs from
//  AVFoundation's authorization system: "what's the current camera-access status,
//  and if it's undecided, prompt and tell me the answer." Keeping it behind a
//  protocol means CameraViewModel's permission gating can be unit-tested without
//  the real AVCaptureDevice permission machinery (which needs a device and shows
//  a system alert). Mirrors the LocationPermissionRequesting pattern from
//  Profile Setup (Core/Location).
//

import Foundation

/// The app's view of camera authorization. AVFoundation has a fourth
/// `.restricted` state (parental controls etc.); from our point of view that's
/// just another flavour of "may not use the camera", so it collapses to `.denied`.
enum CameraPermissionStatus: Sendable {
    /// The user hasn't been asked yet — the only state that shows the system prompt.
    case notDetermined
    case granted
    case denied
}

@MainActor
protocol CameraPermissionRequesting: AnyObject {
    /// The standing authorization status, read without prompting.
    var status: CameraPermissionStatus { get }

    /// Prompt for camera access when undecided (or return the standing decision
    /// if the user has already answered). Never throws — a denial is a normal
    /// outcome the camera screen handles with an explanation.
    func request() async -> CameraPermissionStatus
}
