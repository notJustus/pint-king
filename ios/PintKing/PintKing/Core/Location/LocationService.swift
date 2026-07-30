//
//  LocationService.swift
//  PintKing
//
//  The real CoreLocation-backed LocationProviding. Wraps a CLLocationManager and
//  turns its fire-and-forget, delegate-driven `requestLocation()` into a single
//  `await`ed coordinate, bounded by a 10s timeout (l3-ios-app.md "Pint Logging
//  Flow": "request GPS location (10s timeout, silent fail)").
//
//  Design mirrors CLLocationPermission: `requestLocation()` reports its result
//  asynchronously via the delegate, so we bridge that callback into async/await
//  with a CheckedContinuation. The twist here is the timeout — we race the
//  delegate against a Task.sleep and take whichever finishes first, so a device
//  that never gets a fix doesn't hang the Done button forever.
//
//  Everything resolves to nil rather than throwing: no permission, a location
//  error, or a timeout all mean "log the pint without a location," which is valid.
//

import CoreLocation

@MainActor
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// How long we wait for a fix before giving up and logging without location.
    private let timeout: Duration

    /// Resumed by the delegate (success or failure) for the single in-flight
    /// request; nil the rest of the time. `Coordinate?` because a delegate error
    /// resolves to "no location," same as a timeout.
    private var continuation: CheckedContinuation<Coordinate?, Never>?

    init(timeout: Duration = .seconds(10)) {
        self.timeout = timeout
        super.init()
        manager.delegate = self
    }

    func currentLocation() async -> Coordinate? {
        // No point asking CoreLocation if the user hasn't granted access — it
        // would just error out. Treat anything but "authorized" as no location.
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            return nil
        }

        // Race the delegate-driven fetch against the timeout; take whichever
        // resolves first. `finishFetch` guards the continuation so only the
        // winner resumes it — the loser's resume is a no-op.
        return await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                    self.manager.requestLocation()
                }
            }
            group.addTask { @MainActor in
                try? await Task.sleep(for: self.timeout)
                self.finishFetch(with: nil)   // timed out → no location
                return nil
            }

            // First result wins; cancel the loser and return.
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Resume the in-flight continuation exactly once, then clear it so the losing
    /// racer (or a stray delegate call) can't resume it a second time.
    private func finishFetch(with coordinate: Coordinate?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: coordinate)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        Task { @MainActor in self.finishFetch(with: coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Any failure (no fix, transient error) is a silent no-location.
        Task { @MainActor in self.finishFetch(with: nil) }
    }
}
