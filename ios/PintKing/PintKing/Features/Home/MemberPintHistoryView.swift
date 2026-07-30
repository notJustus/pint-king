//
//  MemberPintHistoryView.swift
//  PintKing
//
//  A member's pint history for the active group (Task 10): a scrollable list of
//  their pints — photo thumbnail, note, drink type, timestamp inline, no separate
//  detail screen (l3-ios-app.md §Screens). Tapping a photo opens a full-size
//  viewer sheet. A thin renderer over MemberPintHistoryViewModel; the fetch and
//  the empty/loading decisions live there so they can be unit-tested without
//  SwiftUI.
//
//  Photos are placeholders for now: pints carry a `photoUrl` path, but loading
//  remote images needs the networking layer, so real photos land with Task 26.
//

import SwiftUI

struct MemberPintHistoryView: View {
    @State private var model: MemberPintHistoryViewModel

    /// The pint whose photo is being viewed full-size, or nil when the viewer is
    /// closed. `PintLog` is Identifiable, so it drives a `.sheet(item:)`.
    @State private var viewedPint: PintLog?

    init(
        userId: UUID,
        memberName: String,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        _model = State(initialValue: MemberPintHistoryViewModel(
            userId: userId,
            memberName: memberName,
            groupRepository: groupRepository,
            pintRepository: pintRepository
        ))
    }

    var body: some View {
        // `SwiftUI.Group` is qualified because the domain model `Group` shadows it.
        SwiftUI.Group {
            if model.isLoading && !model.hasPints {
                skeletonList
            } else if !model.hasPints {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle(model.memberName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sheet(item: $viewedPint) { pint in
            FullSizePhotoView(pint: pint)
        }
    }

    // MARK: - List

    private var historyList: some View {
        List(model.pints) { pint in
            PintHistoryRow(pint: pint) { viewedPint = pint }
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
    }

    // MARK: - Empty & loading states

    private var emptyState: some View {
        ContentUnavailableView(
            "No pints yet",
            systemImage: "mug",
            description: Text("\(model.memberName) hasn't logged a pint in this group.")
        )
    }

    private var skeletonList: some View {
        List(0..<6, id: \.self) { _ in
            SkeletonHistoryRow()
        }
        .listStyle(.plain)
        .disabled(true)
    }
}

// MARK: - Row

/// One pint in the history: a tappable photo thumbnail beside the note, drink
/// type, and timestamp. Tapping the thumbnail invokes `onTapPhoto`.
private struct PintHistoryRow: View {
    let pint: PintLog
    let onTapPhoto: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onTapPhoto) {
                PhotoThumbnail()
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                if let note = pint.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .lineLimit(3)
                }
                HStack(spacing: 8) {
                    if let drink = pint.drinkType {
                        Text(drink.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                    Text(pint.loggedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photo placeholders

/// Square thumbnail placeholder (real photos arrive with networking, Task 26).
private struct PhotoThumbnail: View {
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

/// The full-size photo viewer: a dismissible sheet showing the pint's photo large
/// (placeholder for now) with its note and drink type beneath.
private struct FullSizePhotoView: View {
    let pint: PintLog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(0.15))
                    .overlay {
                        Image(systemName: "mug.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding()

                if let note = pint.note, !note.isEmpty {
                    Text(note).font(.body)
                }
                if let drink = pint.drinkType {
                    Text(drink.rawValue.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A single placeholder row shown while the first load is in flight.
private struct SkeletonHistoryRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    .frame(width: 80, height: 12)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

#Preview("Populated") {
    NavigationStack {
        MemberPintHistoryView(
            userId: MockData.daveId,
            memberName: "Dave Smith",
            groupRepository: MockGroupRepository(),
            pintRepository: MockPintRepository()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        MemberPintHistoryView(
            userId: MockData.sophiaId,   // no pints in Friday Club
            memberName: "Sophia Marchetti",
            groupRepository: MockGroupRepository(),
            pintRepository: MockPintRepository()
        )
    }
}
