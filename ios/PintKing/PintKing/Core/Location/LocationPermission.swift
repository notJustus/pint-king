//
//  LocationPermission.swift
//  PintKing
//
//  A tiny abstraction over the one thing Profile Setup needs from CoreLocation:
//  "ask the user for when-in-use location access and tell me what they chose."
//  Keeping it behind a protocol means the view model can be unit-tested without
//  touching CLLocationManager (which needs a real device/simulator and a
//  delegate callback). The full LocationService — actually reading coordinates
//  at shutter time — lands in Task 14; this is deliberately just the permission
//  request (l3-ios-app.md §"Profile Setup").
//

import Foundation

/// The outcome of a location-permission request, from the app's point of view.
/// CoreLocation has finer-grained states, but Profile Setup only cares whether
/// it may use location going forward.
enum LocationPermissionDecision: Sendable {
    case granted
    case denied
}

@MainActor
protocol LocationPermissionRequesting: AnyObject {
    /// The standing decision, read without prompting. The Settings screen shows
    /// this so the user can see whether location is currently enabled. Mirrors
    /// `CameraPermissionRequesting.status`, but collapsed to granted/denied since
    /// Settings only reports on/off (a not-yet-asked state reads as `.denied`).
    var status: LocationPermissionDecision { get }

    /// Prompt for when-in-use location access (or return the standing decision
    /// if the user has already answered). Never throws — a denial is a normal,
    /// expected outcome that must not block setup.
    func request() async -> LocationPermissionDecision
}
