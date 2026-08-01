//
//  MapViewModelTests.swift
//  PintKingTests
//
//  Task 24: the map. The screen's logic lives in MapViewModel — it fetches pins
//  for the Active_Group inside the current viewport, re-fetches when the camera
//  settles somewhere new or the Personal/Group toggle flips, and passes former
//  members through flagged so the view can grey them. These tests drive that
//  logic directly (no View, no MapKit rendering) against the fixture-backed
//  MockMapRepository, which records every query it serves.
//

import Foundation
import MapKit
import Testing
@testable import PintKing

@MainActor
struct MapViewModelTests {

    /// A region around central London, where the fixture pints are clustered.
    private let londonRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.51, longitude: -0.12),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.35)
    )

    /// A region in the Atlantic, off West Africa — contains no fixture pints.
    private let emptyOceanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
    )

    /// Defaults are built inside the body, not in the parameter list: default
    /// arguments are evaluated in a nonisolated context, and the mocks are
    /// `@MainActor`.
    private func makeViewModel(
        map: MockMapRepository? = nil,
        group: MockGroupRepository? = nil
    ) -> MapViewModel {
        MapViewModel(
            groupRepository: group ?? MockGroupRepository(),
            mapRepository: map ?? MockMapRepository()
        )
    }

    // MARK: - Fetching for the active group + viewport

    @Test func loadFetchesPinsForActiveGroupAndCurrentBox() async {
        let map = MockMapRepository()
        let vm = makeViewModel(map: map)

        await vm.load()

        #expect(map.queries.count == 1)
        #expect(map.queries.first?.groupId == MockData.friday.id)   // seeded Active_Group
        #expect(map.queries.first?.scope == .group)                 // default scope
        // Nothing has narrowed the viewport yet, so the first load asks for everything.
        #expect(map.queries.first?.southWest == MapBoundingBox.world.southWest)
        #expect(map.queries.first?.northEast == MapBoundingBox.world.northEast)
        #expect(vm.hasPins)
    }

    @Test func loadWithNoActiveGroupClearsPinsWithoutFetching() async {
        let map = MockMapRepository()
        let vm = makeViewModel(map: map, group: MockGroupRepository(groups: [], activeGroupId: nil))

        await vm.load()

        #expect(vm.pins.isEmpty)
        #expect(map.queries.isEmpty)
    }

    // MARK: - Scope toggle

    @Test func personalScopeReturnsOnlyTheCurrentUsersPins() async {
        let vm = makeViewModel()

        await vm.select(.personal)

        #expect(vm.scope == .personal)
        #expect(vm.hasPins)
        #expect(vm.pins.allSatisfy { $0.userId == MockData.currentUser.id })
    }

    @Test func groupScopeReturnsEveryMembersPins() async {
        let vm = makeViewModel()

        await vm.load()

        // The Friday Club fixtures include located pints from several authors.
        #expect(Set(vm.pins.map(\.userId)).count > 1)
    }

    @Test func selectingTheCurrentScopeDoesNotRefetch() async {
        let map = MockMapRepository()
        let vm = makeViewModel(map: map)

        await vm.load()
        await vm.select(.group)   // already the default

        #expect(map.queries.count == 1)
    }

    // MARK: - Former members

    @Test func formerMembersPinsAreReturnedFlagged() async {
        let vm = makeViewModel()

        await vm.load()

        // Fred left Friday Club but his located pint remains (Property 23).
        let fredsPins = vm.pins.filter { $0.userId == MockData.fredId }
        #expect(fredsPins.isEmpty == false)
        #expect(fredsPins.allSatisfy { $0.isFormerMember })
        // Everyone still in the group is not flagged.
        #expect(vm.pins.filter { $0.userId != MockData.fredId }.allSatisfy { !$0.isFormerMember })
    }

    // MARK: - Region changes

    @Test func regionChangeNarrowsTheBoxAndRefetches() async {
        let map = MockMapRepository()
        let vm = makeViewModel(map: map)

        await vm.load()
        await vm.regionChanged(to: londonRegion)

        #expect(map.queries.count == 2)
        #expect(vm.boundingBox == MapBoundingBox(region: londonRegion))
        #expect(map.queries.last?.southWest == vm.boundingBox.southWest)
        #expect(map.queries.last?.northEast == vm.boundingBox.northEast)
        #expect(vm.hasPins)
    }

    @Test func regionChangeToTheSameBoxDoesNotRefetch() async {
        let map = MockMapRepository()
        let vm = makeViewModel(map: map)

        await vm.regionChanged(to: londonRegion)
        await vm.regionChanged(to: londonRegion)

        #expect(map.queries.count == 1)
    }

    @Test func pinsOutsideTheViewportAreDropped() async {
        let vm = makeViewModel()

        await vm.load()
        #expect(vm.hasPins)

        await vm.regionChanged(to: emptyOceanRegion)

        #expect(vm.pins.isEmpty)
    }

    // MARK: - Callout (Task 25)

    @Test func tappingAPinOpensACalloutForThatPint() async throws {
        let vm = makeViewModel()
        await vm.load()
        let pin = try #require(vm.pins.first)

        vm.selectPin(pin)

        #expect(vm.hasCallout)
        // The callout renders straight off the selected pin, so "correct data"
        // is the whole pin coming back unchanged.
        #expect(vm.selectedPin == pin)
    }

    @Test func tappingOutsideDismissesTheCallout() async {
        let vm = makeViewModel()
        await vm.load()
        vm.selectPin(vm.pins[0])

        vm.dismissCallout()

        #expect(vm.selectedPin == nil)
        #expect(vm.hasCallout == false)
    }

    @Test func tappingAnotherPinReplacesTheOpenCallout() async {
        let vm = makeViewModel()
        await vm.load()
        vm.selectPin(vm.pins[0])

        vm.selectPin(vm.pins[1])

        #expect(vm.selectedPin == vm.pins[1])
    }

    @Test func panningAwayFromTheSelectedPinDismissesTheCallout() async {
        let vm = makeViewModel()
        await vm.load()
        vm.selectPin(vm.pins[0])

        await vm.regionChanged(to: emptyOceanRegion)

        #expect(vm.selectedPin == nil)
    }

    @Test func aRefetchThatStillContainsTheSelectedPinKeepsTheCalloutOpen() async {
        let vm = makeViewModel()
        await vm.load()
        let pin = vm.pins[0]
        vm.selectPin(pin)

        await vm.regionChanged(to: londonRegion)   // the fixtures are in London

        #expect(vm.selectedPin == pin)
    }

    @Test func switchingToPersonalDismissesAnotherMembersCallout() async throws {
        let vm = makeViewModel()
        await vm.load()
        let othersPin = try #require(vm.pins.first { $0.userId != MockData.currentUser.id })
        vm.selectPin(othersPin)

        await vm.select(.personal)

        #expect(vm.selectedPin == nil)
    }

    // MARK: - Bounding box geometry

    @Test func boundingBoxIsTheRegionsCentrePlusMinusHalfItsSpan() {
        let box = MapBoundingBox(region: londonRegion)

        #expect(box.southWest.latitude == 51.41)
        #expect(box.northEast.latitude == 51.61)
        #expect(abs(box.southWest.longitude - (-0.295)) < 0.000_001)
        #expect(abs(box.northEast.longitude - 0.055) < 0.000_001)
    }

    @Test func boundingBoxClampsASpanThatRunsPastThePoles() {
        let whole = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 400, longitudeDelta: 800)
        )

        let box = MapBoundingBox(region: whole)

        #expect(box == .world)
    }
}
