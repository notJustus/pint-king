//
//  MapViewModel.swift
//  PintKing
//
//  Drives the map on the Home tab (l3-ios-app.md §"Home Tab", requirements §6.8):
//  pins for the Active_Group's located pints inside the current viewport, scoped
//  to just me (`.personal`) or the whole group (`.group`).
//
//  Like the other Home view models it owns only screen-local state — the fetched
//  pins, the scope toggle, and the viewport — and reads the Active_Group *live*
//  off the GroupRepository (shared state with a single owner, l3-ios-app.md §1),
//  so switching group elsewhere re-renders and the next fetch targets the new
//  group for free.
//
//  The viewport lives here rather than in the view because it's a query
//  parameter, not a camera: the map owns where the camera is pointing, and every
//  time it settles it hands the resulting region down to be converted into the
//  box the API is asked about.
//

import Foundation
import MapKit

@MainActor
@Observable
final class MapViewModel {
    /// Pins inside the current box for the current scope. Empty until `load()`
    /// runs, when there's no active group, or when nothing has been logged here.
    private(set) var pins: [MapPin] = []

    /// Whose pints to show. Starts on `.group` — the shared board is the point of
    /// the feature, and it's also the API's default when `?scope=` is omitted.
    private(set) var scope: MapScope = .group

    /// The viewport the pins were fetched for. Starts as the whole world so the
    /// first load has something to ask for before the map has laid out and
    /// reported a region; every camera change narrows it (see `regionChanged`).
    private(set) var boundingBox: MapBoundingBox = .world

    /// True while a fetch is in flight. Only the *first* load (with no pins yet)
    /// shows a progress indicator, so panning doesn't flash it over the map.
    private(set) var isLoading = false

    /// The pin whose callout is open, or nil when none is (requirements §6.7).
    /// This is view-model state rather than view `@State` — unlike the history
    /// screen's photo viewer, the selection has to stay consistent with `pins`:
    /// a pin that leaves the results takes its callout with it (see
    /// `reconcileSelection`), which is a rule worth testing.
    private(set) var selectedPin: MapPin?

    private let groupRepository: any GroupRepositoryProtocol
    private let mapRepository: any MapRepositoryProtocol

    init(
        groupRepository: any GroupRepositoryProtocol,
        mapRepository: any MapRepositoryProtocol
    ) {
        self.groupRepository = groupRepository
        self.mapRepository = mapRepository
    }

    // MARK: - Derived state

    var hasPins: Bool { !pins.isEmpty }

    /// Shown only on the very first fetch — a re-fetch after a pan keeps the
    /// existing pins on screen rather than blanking the map.
    var showsInitialLoading: Bool { isLoading && !hasPins }

    var hasCallout: Bool { selectedPin != nil }

    // MARK: - Actions

    /// Fetch pins for the Active_Group, current scope, and current viewport. With
    /// no active group there's nothing to fetch, so the map is cleared. Failures
    /// leave the pins empty (surfacing the empty state) — the real error path
    /// lands with the networking layer (Task 26), matching the other Home VMs.
    func load() async {
        guard let groupId = groupRepository.activeGroup?.id else {
            pins = []
            reconcileSelection()
            return
        }
        isLoading = true
        defer { isLoading = false }
        pins = (try? await mapRepository.getPintsInBoundingBox(
            groupId: groupId,
            scope: scope,
            southWest: boundingBox.southWest,
            northEast: boundingBox.northEast
        )) ?? []
        reconcileSelection()
    }

    /// Open the callout for a tapped pin, replacing any other that was open.
    func selectPin(_ pin: MapPin) {
        selectedPin = pin
    }

    /// Close the callout — what a tap outside it means.
    func dismissCallout() {
        selectedPin = nil
    }

    /// Keep an open callout consistent with what's actually on the map. A pin
    /// the latest fetch no longer returns (panned out of the viewport, filtered
    /// out by the scope toggle, or in a group that's no longer active) takes its
    /// callout with it; one that's still there is swapped for the freshly
    /// fetched copy, so the callout can never show details the map has since
    /// re-read differently.
    private func reconcileSelection() {
        guard let selected = selectedPin else { return }
        selectedPin = pins.first { $0.id == selected.id }
    }

    /// Switch the Personal/Group toggle and re-fetch the same viewport. A no-op
    /// when unchanged, so re-tapping the active segment doesn't refetch.
    func select(_ scope: MapScope) async {
        guard scope != self.scope else { return }
        self.scope = scope
        await load()
    }

    /// The map camera settled on a new region: convert it to a bounding box and
    /// re-query. An identical box is a no-op — the map reports its region on
    /// first layout too, and that first report is usually the box we already
    /// loaded, so the guard keeps the screen to one fetch per actual move.
    func regionChanged(to region: MKCoordinateRegion) async {
        let box = MapBoundingBox(region: region)
        guard box != boundingBox else { return }
        boundingBox = box
        await load()
    }
}

/// The south-west / north-east corners the map endpoint takes. Converting a
/// MapKit region (a centre plus a span) into corners is the one bit of geometry
/// on this screen, so it lives in a value type that can be tested directly
/// rather than inline in the view.
struct MapBoundingBox: Equatable {
    let southWest: Coordinate
    let northEast: Coordinate

    /// The whole planet — what the first load asks for, before the map has
    /// reported a viewport, so the camera has pins to frame itself around.
    static let world = MapBoundingBox(
        southWest: Coordinate(latitude: -90, longitude: -180),
        northEast: Coordinate(latitude: 90, longitude: 180)
    )

    init(southWest: Coordinate, northEast: Coordinate) {
        self.southWest = southWest
        self.northEast = northEast
    }

    /// Corners of a region: its centre ± half its span, clamped to valid
    /// coordinates. A zoomed-out camera can span past the poles, and the API
    /// (PostGIS) is entitled to reject a box that does.
    init(region: MKCoordinateRegion) {
        let halfLatitude = region.span.latitudeDelta / 2
        let halfLongitude = region.span.longitudeDelta / 2
        southWest = Coordinate(
            latitude: max(region.center.latitude - halfLatitude, -90),
            longitude: max(region.center.longitude - halfLongitude, -180)
        )
        northEast = Coordinate(
            latitude: min(region.center.latitude + halfLatitude, 90),
            longitude: min(region.center.longitude + halfLongitude, 180)
        )
    }
}
