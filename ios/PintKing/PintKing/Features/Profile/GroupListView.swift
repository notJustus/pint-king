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
//  Create and Join are self-presenting sheets owned here (ADR-0098); Group Detail
//  is a value-based push, the whole `GroupSummary` riding the nav path as its own
//  route value (same shape as the Home tab's `MemberRoute` and the Profile tab's
//  `ProfileRoute`), so this screen has no navigation closures left.
//

import SwiftUI

struct GroupListView: View {
    @State private var model: GroupListViewModel

    /// True while the Create Group sheet is presented (Task 20). Owned here rather
    /// than handed up as a closure because the sheet is this screen's own modal and
    /// needs the same `groupRepository`.
    @State private var isCreatingGroup = false

    /// True while the Join Group sheet is presented (Task 21). Owned here for the
    /// same reason as the Create sheet.
    @State private var isJoiningGroup = false

    /// Repositories retained so they can be threaded into the Create/Join sheets
    /// and the Group Detail destination.
    private let groupRepository: any GroupRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol

    init(
        groupRepository: any GroupRepositoryProtocol,
        userRepository: any UserRepositoryProtocol
    ) {
        _model = State(initialValue: GroupListViewModel(groupRepository: groupRepository))
        self.groupRepository = groupRepository
        self.userRepository = userRepository
    }

    /// Opens the Create Group sheet.
    private func onCreate() { isCreatingGroup = true }

    /// Opens the Join Group sheet.
    private func onJoin() { isJoiningGroup = true }

    var body: some View {
        List {
            if model.hasGroups {
                ForEach(model.groups) { group in
                    NavigationLink(value: group) {
                        groupRow(group)
                    }
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
        .navigationDestination(for: GroupSummary.self) { group in
            GroupDetailView(
                group: group,
                groupRepository: groupRepository,
                userRepository: userRepository
            )
            // Detail can rename, remove members, or leave — all of which change
            // this list's rows. Refreshing when it goes away covers every case
            // without the detail screen knowing a list exists (`.task` above only
            // runs once, and does not re-run on a pop).
            .onDisappear { Task { await model.refresh() } }
        }
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
        .sheet(isPresented: $isCreatingGroup) {
            CreateGroupView(groupRepository: groupRepository) {
                // New group created (and set active); dismiss the sheet and refresh
                // so it appears in the list.
                isCreatingGroup = false
                Task { await model.refresh() }
            }
        }
        .sheet(isPresented: $isJoiningGroup) {
            JoinGroupView(groupRepository: groupRepository) {
                // Joined (and set active); dismiss the sheet and refresh so the
                // new group appears in the list.
                isJoiningGroup = false
                Task { await model.refresh() }
            }
        }
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
        GroupListView(
            groupRepository: MockGroupRepository(),
            userRepository: MockUserRepository()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        GroupListView(
            groupRepository: MockGroupRepository(groups: [], activeGroupId: nil),
            userRepository: MockUserRepository()
        )
    }
}
