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
//  Tapping a pin opens its callout (Task 25) as a popover anchored to that pin:
//  the system gives the anchoring and the tap-outside-to-dismiss for free, and
//  the binding routes both back through the view model, which owns the selection.
//
//  Avatars and photos are placeholders for now: pins carry an `avatarUrl` and a
//  `photoUrl`, but loading remote images needs the networking layer (Task 26).
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
                        .onTapGesture { model.selectPin(pin) }
                        .popover(isPresented: calloutBinding(for: pin)) {
                            PintCalloutView(pin: pin)
                                // Without this the popover would adapt into a
                                // sheet on iPhone, losing the anchor to the pin.
                                .presentationCompactAdaptation(.popover)
                        }
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

    /// Whether *this* pin's callout is up. The getter reads the model's single
    /// selection, so opening one callout closes any other; the setter only ever
    /// fires with `false` — that's the system telling us the user tapped outside
    /// — so dismissal has exactly one implementation, in the view model.
    private func calloutBinding(for pin: MapPin) -> Binding<Bool> {
        Binding(
            get: { model.selectedPin?.id == pin.id },
            set: { isPresented in
                if !isPresented { model.dismissCallout() }
            }
        )
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

// MARK: - Callout

/// The tapped pin's pint: photo thumbnail, who logged it, the drink type and
/// note when they were set, and when (requirements §6.7). Read-only — the map is
/// a browsing surface, so there's no action here even on your own pints.
private struct PintCalloutView: View {
    let pin: MapPin

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CalloutThumbnail()
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(pin.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(pin.isFormerMember ? .secondary : .primary)

                if let note = pin.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if let drink = pin.drinkType {
                        Text(drink.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                    Text(pin.loggedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        // A popover sizes itself to its content, and an unconstrained note would
        // stretch it to the screen; this keeps the callout card-shaped.
        .frame(width: 280)
    }
}

/// Square photo placeholder for the callout (real photos arrive with the
/// networking layer, Task 26) — the same stand-in the history rows use.
private struct CalloutThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.tint.opacity(0.15))
            .overlay {
                Image(systemName: "mug.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
    }
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
