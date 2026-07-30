//
//  MyPintsView.swift
//  PintKing
//
//  The My Pints screen (Task 17): the signed-in user's own pints across groups,
//  with a group filter, per-pint edit / delete, and the offline queue's pending /
//  failed rows. A thin renderer over MyPintsViewModel — the fetch, filter, delete
//  window, and queue actions live there so they can be unit-tested without SwiftUI.
//
//  Each row shows the pint's photo (placeholder until networking, Task 26), note,
//  drink type, timestamp, and group name, plus a "pending"/"failed" badge for
//  queued pints. Confirmed pints get swipe-to-edit and swipe-to-delete (delete
//  within the 24h window is confirmed, outside it shows a message); failed pints
//  get retry / discard.
//

import SwiftUI

struct MyPintsView: View {
    @State private var model: MyPintsViewModel

    private let pintRepository: any PintRepositoryProtocol

    /// The pint currently being edited (drives the edit sheet), or nil.
    @State private var editingPint: PintLog?

    /// The pint pending a delete confirmation (within the 24h window), or nil.
    @State private var pintPendingDelete: PintLog?

    init(
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        now: Date = Date()
    ) {
        _model = State(initialValue: MyPintsViewModel(
            groupRepository: groupRepository,
            pintRepository: pintRepository,
            now: now
        ))
        self.pintRepository = pintRepository
    }

    var body: some View {
        // `SwiftUI.Group` is qualified because the domain model `Group` shadows it.
        SwiftUI.Group {
            if model.isLoading && !model.hasRows {
                skeletonList
            } else if !model.hasRows {
                emptyState
            } else {
                pintsList
            }
        }
        .navigationTitle("My Pints")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { filterMenu }
        }
        .task { await model.load() }
        .sheet(item: $editingPint) { pint in
            EditPintView(pint: pint, pintRepository: pintRepository) {
                // A save changed note/drink type — re-fetch so the row updates.
                Task { await model.refresh() }
            }
        }
        .confirmationDialog(
            "Delete this pint?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: pintPendingDelete
        ) { pint in
            Button("Delete", role: .destructive) {
                Task { await model.delete(pintId: pint.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This can't be undone.")
        }
        .alert(
            "Can't delete pint",
            isPresented: errorBinding,
            actions: { Button("OK") {} },
            message: { Text(model.errorMessage ?? "") }
        )
    }

    // MARK: - Filter

    private var filterMenu: some View {
        Menu {
            Button {
                Task { await model.selectGroup(nil) }
            } label: {
                Label("All Groups", systemImage: model.selectedGroupId == nil ? "checkmark" : "")
            }
            ForEach(model.groups) { group in
                Button {
                    Task { await model.selectGroup(group.id) }
                } label: {
                    Label(group.name, systemImage: model.selectedGroupId == group.id ? "checkmark" : "")
                }
            }
        } label: {
            Label(model.selectedFilterName, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: - List

    private var pintsList: some View {
        List {
            ForEach(model.rows) { row in
                MyPintRowView(row: row)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        swipeActions(for: row)
                    }
            }
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
    }

    /// Swipe actions differ by status: confirmed pints edit / delete; failed pints
    /// retry / discard; a still-pending upload offers only discard.
    @ViewBuilder private func swipeActions(for row: MyPintRow) -> some View {
        switch row.status {
        case .confirmed:
            Button(role: .destructive) {
                if model.canDelete(row.pint) {
                    pintPendingDelete = row.pint       // ask first, within the window
                } else {
                    Task { await model.delete(pintId: row.pint.id) }   // surfaces the message
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingPint = row.pint
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

        case .failed:
            Button {
                Task { await model.retry(pintId: row.pint.id) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
            Button(role: .destructive) {
                Task { await model.discard(pintId: row.pint.id) }
            } label: {
                Label("Discard", systemImage: "trash")
            }

        case .pending:
            Button(role: .destructive) {
                Task { await model.discard(pintId: row.pint.id) }
            } label: {
                Label("Discard", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty & loading states

    private var emptyState: some View {
        ContentUnavailableView(
            "No pints yet",
            systemImage: "mug",
            description: Text("Pints you log will show up here.")
        )
    }

    private var skeletonList: some View {
        List(0..<6, id: \.self) { _ in
            SkeletonMyPintRow()
        }
        .listStyle(.plain)
        .disabled(true)
    }

    // MARK: - Bindings

    /// True when a pint is queued for delete confirmation; setting false clears it.
    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pintPendingDelete != nil },
            set: { if !$0 { pintPendingDelete = nil } }
        )
    }

    /// True when there's an inline error to show in an alert.
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { _ in }
        )
    }
}

// MARK: - Row

/// One pint in My Pints: photo thumbnail beside the note, drink type, group name,
/// timestamp, and — for queued pints — a pending / failed badge.
private struct MyPintRowView: View {
    let row: MyPintRow

    private var pint: PintLog { row.pint }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PhotoThumbnail()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                if let note = pint.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let drink = pint.drinkType {
                        Text(drink.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                    Text(row.groupName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(pint.loggedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(status: row.status)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// A small pill for a queued pint's upload status. Confirmed pints show nothing.
private struct StatusBadge: View {
    let status: MyPintRow.Status

    var body: some View {
        switch status {
        case .confirmed:
            EmptyView()
        case .pending:
            badge("Pending", color: .orange)
        case .failed:
            badge("Failed", color: .red)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }
}

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

/// A single placeholder row shown while the first load is in flight.
private struct SkeletonMyPintRow: View {
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
        MyPintsView(
            groupRepository: MockGroupRepository(),
            pintRepository: MockPintRepository(),
            now: MockData.now
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        MyPintsView(
            groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
            pintRepository: MockPintRepository(pints: [], pending: []),
            now: MockData.now
        )
    }
}
