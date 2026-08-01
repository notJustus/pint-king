//
//  MockGroupRepository.swift
//  PintKing
//
//  In-memory group store. Keeps mutable copies of the group list, each group's
//  members, and the active group so switching / joining / leaving / admin edits
//  persist for the session and are observable by the Home and Group screens.
//  Join/leave/admin logic is just enough to exercise the UI — the real rules are
//  enforced server-side.
//

import Foundation

@MainActor
@Observable
final class MockGroupRepository: GroupRepositoryProtocol {
    private var groups: [Group]
    private var membersByGroup: [UUID: [GroupMember]]
    private(set) var activeGroup: Group?

    /// The user whose membership/admin status the mock reasons about (defaults to
    /// the mock signed-in user). Used to decide leave/fallback behaviour.
    private let currentUserId: UUID

    /// When true, the next `createGroup(name:)` throws `.validationFailed` instead
    /// of succeeding, standing in for the API's 99-group limit (requirements §5.2)
    /// so the Create Group screen's error path can be exercised without a backend.
    var shouldFailCreate = false

    init(
        groups: [Group] = MockData.groups,
        activeGroupId: UUID? = MockData.currentUser.activeGroupId,
        currentUserId: UUID = MockData.currentUser.id
    ) {
        self.groups = groups
        self.currentUserId = currentUserId
        self.membersByGroup = Dictionary(
            uniqueKeysWithValues: groups.map { ($0.id, MockData.members(of: $0.id)) }
        )
        self.activeGroup = groups.first { $0.id == activeGroupId }
    }

    func getGroups() async throws -> [GroupSummary] {
        groups.map { group in
            let members = membersByGroup[group.id] ?? []
            let role = members.first { $0.userId == currentUserId }?.role ?? .member
            return GroupSummary(
                id: group.id, name: group.name, inviteCode: group.inviteCode,
                role: role, memberCount: members.count
            )
        }
    }

    func getGroupDetail(groupId: UUID) async throws -> GroupDetail {
        guard let group = groups.first(where: { $0.id == groupId }) else {
            throw APIError.notFound
        }
        return GroupDetail(group: group, members: membersByGroup[groupId] ?? [])
    }

    func createGroup(name: String) async throws -> Group {
        if shouldFailCreate {
            throw APIError.validationFailed
        }
        let group = Group(
            id: UUID(), name: name, inviteCode: Self.randomInviteCode(),
            createdBy: currentUserId, createdAt: MockData.now
        )
        groups.append(group)
        membersByGroup[group.id] = [
            GroupMember(
                id: UUID(), userId: currentUserId, groupId: group.id, role: .admin,
                joinedAt: MockData.now, displayName: MockData.currentUser.displayName,
                avatarUrl: MockData.currentUser.avatarUrl
            )
        ]
        activeGroup = group   // new group becomes active
        return group
    }

    func joinGroup(inviteCode: String) async throws -> Group {
        // Already a member of a group with this code?
        if groups.contains(where: { $0.inviteCode == inviteCode }) {
            throw APIError.conflict
        }
        // Removed from this group by an admin — the code resolves but the join is
        // refused (Property 11c).
        if inviteCode == MockData.blockedInviteCode {
            throw APIError.forbidden
        }
        guard inviteCode == MockData.joinableInviteCode else {
            throw APIError.notFound
        }
        let group = MockData.joinableGroup
        groups.append(group)
        membersByGroup[group.id] = [
            GroupMember(
                id: UUID(), userId: currentUserId, groupId: group.id, role: .member,
                joinedAt: MockData.now, displayName: MockData.currentUser.displayName,
                avatarUrl: MockData.currentUser.avatarUrl
            )
        ]
        activeGroup = group   // joined group becomes active
        return group
    }

    func leaveGroup(groupId: UUID) async throws {
        groups.removeAll { $0.id == groupId }
        membersByGroup[groupId] = nil
        // Active-group fallback: if we left the active group, fall back to the
        // most recently created remaining group (or nil).
        if activeGroup?.id == groupId {
            activeGroup = groups.max { $0.createdAt < $1.createdAt }
        }
    }

    func removeMember(groupId: UUID, userId: UUID) async throws {
        membersByGroup[groupId]?.removeAll { $0.userId == userId }
    }

    func promoteMember(groupId: UUID, userId: UUID) async throws {
        guard let index = membersByGroup[groupId]?.firstIndex(where: { $0.userId == userId })
        else { throw APIError.notFound }
        let m = membersByGroup[groupId]![index]
        membersByGroup[groupId]![index] = GroupMember(
            id: m.id, userId: m.userId, groupId: m.groupId, role: .admin,
            joinedAt: m.joinedAt, displayName: m.displayName, avatarUrl: m.avatarUrl
        )
    }

    func regenerateInviteCode(groupId: UUID) async throws -> Group {
        try replaceGroup(groupId) { g in
            Group(id: g.id, name: g.name, inviteCode: Self.randomInviteCode(),
                  createdBy: g.createdBy, createdAt: g.createdAt)
        }
    }

    @discardableResult
    func updateGroupName(groupId: UUID, name: String) async throws -> Group {
        try replaceGroup(groupId) { g in
            Group(id: g.id, name: name, inviteCode: g.inviteCode,
                  createdBy: g.createdBy, createdAt: g.createdAt)
        }
    }

    func switchActiveGroup(groupId: UUID) async throws {
        guard let group = groups.first(where: { $0.id == groupId }) else {
            throw APIError.notFound
        }
        activeGroup = group
    }

    // MARK: - Helpers

    /// Replace the group with `id` by applying `transform`, keeping `activeGroup`
    /// in sync, and return the new value. Throws `.notFound` if absent.
    private func replaceGroup(_ id: UUID, _ transform: (Group) -> Group) throws -> Group {
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        let updated = transform(groups[index])
        groups[index] = updated
        if activeGroup?.id == id { activeGroup = updated }
        return updated
    }

    private static func randomInviteCode() -> String {
        // Deterministic-enough for a mock: no Math.random / Date needed. Uses a
        // UUID's hex (0-9a-f), uppercased, first 8 chars — always 8 alphanumerics.
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
    }
}
