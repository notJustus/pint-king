//
//  MapContentView.swift
//  PintKing
//
//  The map on the Home tab: a Personal/Group toggle over a MapKit map whose pins
//  are the group's located pints, each drawn as its author's avatar and greyed
//  out when that author has left the group (Property 23).
//
//  A thin renderer over MapViewModel — the fetch, the scope, and the viewport →
//  bounding-box conversion all live there. The one thing the view owns is the
//  camera: `.automatic` frames whatever pins came back on first load, and from
//  then on the user drives it, each settled gesture handing the new region down
//  to be re-queried.
//
//  Avatars are initials placeholders for now: pins carry an `avatarUrl`, but
//  loading remote images needs the networking layer (Task 26). Tapping a pin
//  opens the callout in Task 25.
//

import SwiftUI
import MapKit

struct MapContentView: View {
    @State private var model: MapViewModel
    @State private var position: MapCameraPosition = .automatic

    init(
        groupRepository: any GroupRepositoryProtocol,
        mapRepository: any MapRepositoryProtocol
    ) {
        _model = State(initialValue: MapViewModel(
            groupRepository: groupRepository,
            mapRepository: mapRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            scopePicker

            ZStack {
                map

                if model.showsInitialLoading {
                    ProgressView()
                } else if !model.hasPins {
                    emptyState
                }
            }
        }
        .task { await model.load() }
    }

    // MARK: - Scope toggle

    private var scopePicker: some View {
        Picker("Scope", selection: scopeBinding) {
            Text("Personal").tag(MapScope.personal)
            Text("Group").tag(MapScope.group)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    /// Forwards a segment tap to the view model, which re-fetches the same
    /// viewport. The getter reflects the model, so the control can't drift.
    private var scopeBinding: Binding<MapScope> {
        Binding(
            get: { model.scope },
            set: { scope in Task { await model.select(scope) } }
        )
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $position) {
            ForEach(model.pins) { pin in
                Annotation(pin.displayName, coordinate: coordinate(of: pin)) {
                    MapAvatarPin(name: pin.displayName, isFormerMember: pin.isFormerMember)
                }
            }
        }
        // `.onEnd` fires when a pan/zoom settles rather than on every frame, so
        // the re-fetch is one query per gesture and needs no debouncing here.
        .onMapCameraChange(frequency: .onEnd) { context in
            Task { await model.regionChanged(to: context.region) }
        }
    }

    private func coordinate(of pin: MapPin) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
    }

    // MARK: - Empty state

    /// Overlaid on the map rather than replacing it — the map is still the thing
    /// you'd pan to look elsewhere, so hiding it would strand the user.
    private var emptyState: some View {
        Text("No pints here yet")
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
    }
}

/// One pin: a circular initials avatar with a pointer, tinted for a current
/// member and grey for a former one (Property 23 — visually distinct, not hidden).
private struct MapAvatarPin: View {
    let name: String
    let isFormerMember: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(.background)
                    .overlay(Circle().stroke(tint, lineWidth: 2))
                Text(InitialsGenerator.initials(from: name))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(tint)
                .offset(y: -3)
        }
        .opacity(isFormerMember ? 0.6 : 1)
    }

    private var tint: Color { isFormerMember ? .secondary : .accentColor }
}

#Preview("Populated") {
    MapContentView(
        groupRepository: MockGroupRepository(),
        mapRepository: MockMapRepository()
    )
}

#Preview("No pins") {
    MapContentView(
        groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
        mapRepository: MockMapRepository()
    )
}
