//
//  LocationProviding.swift
//  PintKing
//
//  The one thing pint logging needs from CoreLocation at shutter time: "give me
//  the current GPS coordinate if you can, quickly, and don't make a fuss if you
//  can't." A pint with no location is perfectly valid (requirements §3,
//  l3-ios-app.md "Pint Logging Flow"), so this never throws and never blocks —
//  a timeout, a denial, or any error all resolve to nil.
//
//  Keeping it behind a protocol lets the post-capture view model be unit-tested
//  without CLLocationManager (which needs a device and a delegate callback). The
//  real CoreLocation-backed implementation is LocationService; MockLocationProvider
//  backs previews and tests.
//
//  This is separate from LocationPermissionRequesting (Task 7): that asks *may we
//  use location?* during Profile Setup; this reads *where are we?* at shutter time.
//

import Foundation

@MainActor
protocol LocationProviding: AnyObject {
    /// Best-effort current location, bounded by a short timeout. Returns the
    /// coordinate if one arrives in time, or nil on timeout / permission denied /
    /// any error. Never throws — a locationless pint is a normal outcome that must
    /// not block logging.
    func currentLocation() async -> Coordinate?
}
