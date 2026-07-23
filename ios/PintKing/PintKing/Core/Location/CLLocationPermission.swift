//
//  CLLocationPermission.swift
//  PintKing
//
//  The real CoreLocation-backed LocationPermissionRequesting. Wraps a
//  CLLocationManager: `request()` calls requestWhenInUseAuthorization() and
//  suspends until the manager reports an authorization change via its delegate,
//  then maps the CLAuthorizationStatus to a granted/denied decision.
//
//  Why the continuation dance: requestWhenInUseAuthorization() is fire-and-forget
//  — the answer arrives asynchronously on the delegate. We bridge that callback
//  into async/await with a CheckedContinuation so callers can just `await`.
//

import CoreLocation

@MainActor
final class CLLocationPermission: NSObject, LocationPermissionRequesting, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// Resumed by the delegate when the user answers. Held for the duration of a
    /// single in-flight request; nil the rest of the time.
    private var continuation: CheckedContinuation<LocationPermissionDecision, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() async -> LocationPermissionDecision {
        // If the user has already decided, don't prompt again — return the
        // standing status. `.notDetermined` is the only state that shows the
        // system prompt.
        let status = manager.authorizationStatus
        if status != .notDetermined {
            return Self.decision(for: status)
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // The delegate can also fire for reasons unrelated to our prompt; only
        // resume if we're actually waiting on an answer.
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(returning: Self.decision(for: status))
        }
    }

    private static func decision(for status: CLAuthorizationStatus) -> LocationPermissionDecision {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .granted
        default:
            // .denied, .restricted, and (defensively) .notDetermined all mean
            // "we may not use location" from the app's point of view.
            return .denied
        }
    }
}
