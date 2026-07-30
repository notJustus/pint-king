//
//  GroupListView.swift
//  PintKing
//
//  The Group List screen (Profile → My Groups, Task 19): every group the user
//  belongs to, each row showing the name, member count, and an admin badge where
//  the user is an admin. Toolbar actions open Create / Join; tapping a row opens
//  Group Detail.
//
//  A thin renderer over GroupListViewModel — all state and loading live there.
//  The three destinations (Create, Join, Detail) land in Tasks 20–22, so they're
//  injected as closures defaulting to `{}` — the "wire the destination later"
//  convention used by the group switcher (Task 8) and profile rows (Task 15).
//

import SwiftUI

struct GroupListView: View {
    @State private var model: GroupListViewModel

    /// Opens Create Group (Task 20).
    private let onCreate: () -> Void
    /// Opens Join Group (Task 21).
    private let onJoin: () -> Void
    /// Opens Group Detail for the tapped group (Task 22).
    private let onSelect: (GroupSummary) -> Void

    init(
        groupRepository: any GroupRepositoryProtocol,
        onCreate: @escaping () -> Void = {},
        onJoin: @escaping () -> Void = {},
        onSelect: @escaping (GroupSummary) -> Void = { _ in }
    ) {
        _model = State(initialValue: GroupListViewModel(groupRepository: groupRepository))
        self.onCreate = onCreate
        self.onJoin = onJoin
        self.onSelect = onSelect
    }

    var body: some View {
        List {
            if model.hasGroups {
                ForEach(model.groups) { group in
                    Button { onSelect(group) } label: {
                        groupRow(group)
                    }
                    .foregroundStyle(.primary)
                }
            } else if model.isLoading {
                // First-load skeleton: a few redacted placeholder rows.
                ForEach(0..<3, id: \.self) { _ in
                    groupRow(Self.placeholder)
                        .redacted(reason: .placeholder)
                }
            }
        }
        .overlay {
            if !model.hasGroups && !model.isLoading {
                emptyState
            }
        }
        .navigationTitle("My Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Create Group", systemImage: "plus", action: onCreate)
                    Button("Join Group", systemImage: "person.badge.plus", action: onJoin)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await model.load() }
        .refreshable { await model.refresh() }
    }

    /// One group row: name + member count, with an admin badge when the user is
    /// an admin of that group.
    private func groupRow(_ group: GroupSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                Text("^[\(group.memberCount) member](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if group.role == .admin {
                Text("Admin")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// Shown when the user belongs to no groups: a prompt plus Create / Join.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Groups Yet", systemImage: "person.3")
        } description: {
            Text("Create a group or join one with an invite code to start tracking pints.")
        } actions: {
            Button("Create Group", action: onCreate)
                .buttonStyle(.borderedProminent)
            Button("Join Group", action: onJoin)
                .buttonStyle(.bordered)
        }
    }

    /// A stand-in row used only for the redacted first-load skeleton.
    private static let placeholder = GroupSummary(
        id: UUID(), name: "Group name", inviteCode: "········",
        role: .member, memberCount: 0
    )
}

#Preview("Has groups") {
    NavigationStack {
        GroupListView(groupRepository: MockGroupRepository())
    }
}

#Preview("Empty") {
    NavigationStack {
        GroupListView(groupRepository: MockGroupRepository(groups: [], activeGroupId: nil))
    }
}
