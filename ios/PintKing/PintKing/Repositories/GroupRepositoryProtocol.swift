//
//  GroupRepositoryProtocol.swift
//  PintKing
//
//  Group membership, CRUD, invite codes, admin actions, and the app's single
//  Active_Group. Active group is shared state (the Home tab and "+" button both
//  read it), so it lives here and is exposed as an observable property plus a
//  mutator, per l3-ios-app.md §1 "State Ownership".
//

import Foundation

@MainActor
protocol GroupRepositoryProtocol: AnyObject {
    /// The groups the current user belongs to.
    func getGroups() async throws -> [Group]

    /// Full detail (group + members) for one group. Maps to GET /groups/{id}.
    func getGroupDetail(groupId: UUID) async throws -> GroupDetail

    /// Create a group; the creator becomes admin. On success it is set as the
    /// active group (l3-ios-app.md, Create First Group flow).
    func createGroup(name: String) async throws -> Group

    /// Join a group by its 8-char invite code and set it active. Throws
    /// `.notFound` / `.conflict` / `.forbidden` for the corresponding cases
    /// (Property 11).
    func joinGroup(inviteCode: String) async throws -> Group

    /// Leave a group. Active-group fallback is applied if the left group was active.
    func leaveGroup(groupId: UUID) async throws

    /// Admin: remove a member from a group.
    func removeMember(groupId: UUID, userId: UUID) async throws

    /// Admin: promote a member to admin.
    func promoteMember(groupId: UUID, userId: UUID) async throws

    /// Admin: rotate the invite code, invalidating the old one. Returns the group
    /// with its new code.
    func regenerateInviteCode(groupId: UUID) async throws -> Group

    /// Admin: rename a group (1–50 chars). Returns the updated group.
    @discardableResult
    func updateGroupName(groupId: UUID, name: String) async throws -> Group

    /// The current Active_Group, or nil if the user belongs to none. Observable
    /// shared state: the "+" button is disabled when this is nil.
    var activeGroup: Group? { get }

    /// Switch the Active_Group to `groupId` (must be one the user belongs to).
    func switchActiveGroup(groupId: UUID) async throws
}
