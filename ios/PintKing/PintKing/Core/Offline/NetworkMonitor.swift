//
//  NetworkMonitor.swift
//  PintKing
//
//  "Is there a network right now, and tell me when one comes back." The offline
//  queue needs both halves: the first so it doesn't burn retry attempts on a
//  request that cannot leave the device, the second because reconnecting is the
//  event that should drain the queue.
//
//  It is a protocol for the same reason the camera and location are: a unit test
//  cannot turn Wi-Fi off.
//

import Foundation
import Network

@MainActor
protocol NetworkMonitoring: AnyObject {

    /// Whether a network path is currently available. This is a hint, not a
    /// guarantee — a captive portal or a dying signal still says `true`, which is
    /// why the queue also handles a transport failure on a request it did send.
    var isConnected: Bool { get }

    /// Called when connectivity returns after being unavailable. Assigned rather
    /// than subscribed because there is exactly one listener (the queue), the same
    /// shape as `NetworkClient.setAuthenticationLostHandler`.
    var onConnectionRestored: (@MainActor () -> Void)? { get set }
}

@MainActor
@Observable
final class NetworkMonitor: NetworkMonitoring {

    /// Starts optimistic. `NWPathMonitor` reports asynchronously, so the first
    /// moments of a launch have no answer yet — and the failure mode of guessing
    /// "connected" (one request that fails and is retried) is far cheaper than
    /// guessing "offline" (a queue that refuses to drain until the path handler
    /// fires).
    private(set) var isConnected: Bool = true

    @ObservationIgnored
    var onConnectionRestored: (@MainActor () -> Void)?

    @ObservationIgnored
    private nonisolated let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.apply(connected: connected) }
        }
        monitor.start(queue: DispatchQueue(label: "com.pintking.network-monitor"))
    }

    deinit {
        monitor.cancel()
    }

    private func apply(connected: Bool) {
        let wasConnected = isConnected
        isConnected = connected
        // Only the offline → online edge is interesting; NWPathMonitor also fires
        // on interface changes (Wi-Fi → cellular) that stay satisfied throughout.
        if connected && !wasConnected {
            onConnectionRestored?()
        }
    }
}
