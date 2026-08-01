//
//  GroupDetailView.swift
//  PintKing
//
//  The Group Detail screen (Profile → My Groups → a group, Task 22): the member
//  list, admin actions where the user is an admin, and Leave Group.
//
//  A thin renderer over GroupDetailViewModel — every rule (who may manage whom,
//  what leaving does) is derived there. The view's own @State holds only what is
//  purely presentational: which prompt is on screen and which member it targets.
//
//  The Invite screen is Task 23, so that row calls an injected closure defaulting
//  to `{}` — the "wire the destination later" convention used by the group
//  switcher (Task 8) and profile rows (Task 15).
//
//  Avatars are initials placeholders until networking (Task 26), matching the
//  leaderboard, history, and profile screens.
//

import SwiftUI

struct GroupDetailView: View {
    @State private var model: GroupDetailViewModel

    /// True while the rename prompt is up (admin only).
    @State private var isRenaming = false

    /// The member an admin has chosen to remove, driving the destructive
    /// confirmation. Nil when no confirmation is up.
    @State private var memberToRemove: GroupMember?

    /// True while the leave confirmation is up (the `.deletesGroup` / `.simple`
    /// outcomes).
    @State private var isConfirmingLeave = false

    /// True while the "promote someone first" prompt is up — the `.promoteFirst`
    /// outcome, which never reaches a confirmation because the leave is refused.
    @State private var isShowingPromotePrompt = false

    @Environment(\.dismiss) private var dismiss

    /// Opens the Invite screen (Task 23).
    private let onInvite: () -> Void

    init(
        group: GroupSummary,
        groupRepository: any GroupRepositoryProtocol,
        userRepository: any UserRepositoryProtocol,
        onInvite: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: GroupDetailViewModel(
            group: group,
            groupRepository: groupRepository,
            userRepository: userRepository
        ))
        self.onInvite = onInvite
    }

    var body: some View {
        List {
            Section {
                Button(action: onInvite) {
                    Label("Invite Members", systemImage: "person.badge.plus")
                }
            }

            Section("Members") {
                if model.members.isEmpty && model.isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        memberRow(Self.placeholder)
                            .redacted(reason: .placeholder)
                    }
                } else {
                    ForEach(model.members) { member in
                        memberRow(member)
                    }
                }
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                leaveButton
            }
        }
        .navigationTitle(model.groupName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button("Rename Group", systemImage: "pencil") {
                        model.beginRename()
                        isRenaming = true
                    }
                }
            }
        }
        .task { await model.load() }
        .refreshable { await model.refresh() }
        .alert("Rename Group", isPresented: $isRenaming) {
            TextField("Group name", text: $model.nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task { await model.rename() }
            }
            .disabled(!model.isNameDraftValid)
        } message: {
            Text("Enter a new name for this group (1–50 characters).")
        }
        .confirmationDialog(
            "Remove \(memberToRemove?.displayName ?? "member")?",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Remove", role: .destructive) {
                Task { await model.removeMember(userId: member.userId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Their existing pints stay on the leaderboard, marked as a former member.")
        }
        .confirmationDialog(
            "Leave \(model.groupName)?",
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task { await model.leave() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(leaveConfirmationMessage)
        }
        .alert("Promote Someone First", isPresented: $isShowingPromotePrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're the only admin of this group. Promote another member to admin before you leave.")
        }
        .onChange(of: model.didLeave) { _, didLeave in
            if didLeave { dismiss() }
        }
    }

    /// One member row: initials avatar, name, an admin badge, and — for admins —
    /// a menu of actions on everyone but themselves.
    private func memberRow(_ member: GroupMember) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(name: member.displayName)
                .frame(width: 40, height: 40)

            Text(member.displayName)
                .font(.body)

            Spacer()

            if member.role == .admin {
                Text("Admin")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }

            if model.canManage(member) {
                Menu {
                    if model.canPromote(member) {
                        Button("Promote to Admin", systemImage: "star") {
                            Task { await model.promoteMember(userId: member.userId) }
                        }
                    }
                    Button("Remove from Group", systemImage: "person.badge.minus", role: .destructive) {
                        memberToRemove = member
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Leave Group. Which prompt it raises depends on the view model's outcome:
    /// a sole admin with other members is told to promote someone (no API call),
    /// everyone else gets a destructive confirmation.
    private var leaveButton: some View {
        Button(role: .destructive) {
            if model.leaveOutcome == .promoteFirst {
                isShowingPromotePrompt = true
            } else {
                isConfirmingLeave = true
            }
        } label: {
            HStack {
                Text("Leave Group")
                if model.isLeaving {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(model.isLeaving)
    }

    /// The confirmation copy, which differs when leaving would delete the group.
    private var leaveConfirmationMessage: String {
        switch model.leaveOutcome {
        case .deletesGroup:
            return "You're the only member. Leaving will permanently delete this group."
        default:
            return "You'll stop appearing on this group's leaderboard. Your existing pints stay, marked as a former member."
        }
    }

    /// A stand-in member used only for the redacted first-load skeleton.
    private static let placeholder = GroupMember(
        id: UUID(), userId: UUID(), groupId: UUID(), role: .member,
        joinedAt: .now, displayName: "Member name", avatarUrl: nil
    )
}

/// Circular initials placeholder (real avatars arrive with networking, Task 26).
/// Kept private to this file, like the leaderboard's and profile's copies.
private struct AvatarCircle: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            Text(InitialsGenerator.initials(from: name))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

#Preview("Admin (sole admin, has members)") {
    NavigationStack {
        GroupDetailView(
            group: GroupSummary(
                id: MockData.fridayId, name: "Friday Club", inviteCode: "aB3dE6fH",
                role: .admin, memberCount: 4
            ),
            groupRepository: MockGroupRepository(),
            userRepository: MockUserRepository()
        )
    }
}

#Preview("Member") {
    NavigationStack {
        GroupDetailView(
            group: GroupSummary(
                id: MockData.sundayId, name: "Sunday League", inviteCode: "kM9nP2qR",
                role: .member, memberCount: 4
            ),
            groupRepository: MockGroupRepository(),
            userRepository: MockUserRepository()
        )
    }
}
