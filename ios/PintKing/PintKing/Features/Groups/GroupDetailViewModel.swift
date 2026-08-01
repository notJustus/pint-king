//
//  GroupDetailViewModel.swift
//  PintKing
//
//  Drives the Group Detail screen (Profile → My Groups → a group, Task 22;
//  requirements §5.11–5.13, §5.17–5.18, l3-ios-app.md §"Leave Group"): the member
//  list, the admin actions (remove, promote, rename), and leaving the group.
//
//  Like the other view models it owns only screen-local state — the fetched
//  members, the rename draft, loading/error flags. The group itself, the member
//  list, and the Active_Group all live on the GroupRepository.
//
//  Two things are worth calling out:
//
//  1. **Role comes from the loaded member list, not the caller.** The screen is
//     entered from the group list, whose `GroupSummary` already carries the
//     caller's role — but that is a snapshot of a list fetched earlier, and this
//     screen *changes* roles. So the summary is used only to seed the title
//     (`groupName`, avoiding a blank nav bar during the first load, the same way
//     MemberPintHistoryViewModel takes `memberName`), while `isAdmin` is derived
//     from the freshly-loaded members. Before the load resolves `isAdmin` is
//     false, so the admin affordances appear rather than disappear — the safe
//     direction for a wrong guess.
//
//  2. **Leaving is a three-way decision, computed client-side.** `leaveOutcome`
//     mirrors Property 15 (and the API's rejection) so the screen can pick the
//     right prompt *before* calling anything: a sole admin with other members must
//     promote someone first (the leave is never attempted), a sole admin who is
//     also the only member is warned the group will be deleted, and everyone else
//     gets a plain confirmation. The API remains the authority — this is a UX gate
//     over the same rule, the same relationship `MyPintsViewModel.canDelete(_:)`
//     has with the 24h window.
//

import Foundation

@MainActor
@Observable
final class GroupDetailViewModel {

    /// What happens if the user leaves this group — decides which prompt the
    /// screen shows, and whether `leave()` is allowed to call the API at all.
    enum LeaveOutcome: Equatable {
        /// Sole admin with other members: the group would be left admin-less, so
        /// the user must promote someone before leaving (requirements §5.18).
        case promoteFirst
        /// Sole admin and only member: leaving deletes the group.
        case deletesGroup
        /// Not the sole admin: an ordinary leave.
        case simple
    }

    /// The group's name — seeded from the row that opened the screen so the title
    /// renders immediately, then kept in step with loads and renames.
    private(set) var groupName: String

    /// The group's members, in the order the repository returns them (join order).
    /// Empty until `load()` runs.
    private(set) var members: [GroupMember] = []

    /// True only during the first load, so the view shows skeleton rows once and
    /// a refresh after an admin action doesn't blank the list.
    private(set) var isLoading = false

    /// True while the leave call is in flight; the button shows a spinner.
    private(set) var isLeaving = false

    /// Human-readable error shown inline (a failed admin action, an invalid name,
    /// a rejected leave), or nil when there's nothing to show.
    private(set) var errorMessage: String?

    /// Flips to true once the user has left; the view observes it and pops back
    /// to the group list.
    private(set) var didLeave = false

    /// The rename field's text. Settable so the alert's TextField can bind to it;
    /// `beginRename()` seeds it from the current name.
    var nameDraft = ""

    /// The group being shown. Immutable input, not state — this screen is about
    /// one specific group (same shape as MemberPintHistoryViewModel's `userId`).
    let groupId: UUID

    /// The signed-in user's id, resolved in `load()`. Needed to tell "my" row from
    /// everyone else's: a user can neither remove nor promote themselves.
    private var currentUserId: UUID?

    private let groupRepository: any GroupRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol

    /// Group-name bounds, matching the API and CreateGroupViewModel
    /// (requirements §5.1).
    private static let nameRange = 1...50

    init(
        group: GroupSummary,
        groupRepository: any GroupRepositoryProtocol,
        userRepository: any UserRepositoryProtocol
    ) {
        self.groupId = group.id
        self.groupName = group.name
        self.groupRepository = groupRepository
        self.userRepository = userRepository
    }

    // MARK: - Derived state

    /// The signed-in user's own membership row, once both the profile and the
    /// members have loaded.
    private var currentMember: GroupMember? {
        guard let currentUserId else { return nil }
        return members.first { $0.userId == currentUserId }
    }

    /// True when the signed-in user is an admin of this group — gates every admin
    /// affordance (rename, remove, promote).
    var isAdmin: Bool {
        currentMember?.role == .admin
    }

    /// True when an admin may act on this member: admins can manage anyone but
    /// themselves (self-removal is "leave", self-promotion is meaningless).
    func canManage(_ member: GroupMember) -> Bool {
        isAdmin && member.userId != currentUserId
    }

    /// True when this member can be promoted — manageable, and not already admin.
    func canPromote(_ member: GroupMember) -> Bool {
        canManage(member) && member.role == .member
    }

    /// What leaving would do, per Property 15. See `LeaveOutcome`.
    var leaveOutcome: LeaveOutcome {
        let adminCount = members.count { $0.role == .admin }
        guard isAdmin, adminCount == 1 else { return .simple }
        let hasOtherMembers = members.contains { $0.userId != currentUserId }
        return hasOtherMembers ? .promoteFirst : .deletesGroup
    }

    /// True when the rename draft is 1–50 characters after trimming. Drives the
    /// Save button's enabled state.
    var isNameDraftValid: Bool {
        Self.nameRange.contains(trimmedNameDraft.count)
    }

    /// The rename draft with leading/trailing whitespace removed — what actually
    /// gets saved and validated.
    private var trimmedNameDraft: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Loading

    /// Fetch the group's detail plus the signed-in user's id. First load flips
    /// `isLoading` for the skeleton; failures leave the list empty — the real
    /// error path lands with networking (Task 26), matching the other view models'
    /// silent `try?`.
    func load() async {
        if members.isEmpty { isLoading = true }
        defer { isLoading = false }

        currentUserId = (try? await userRepository.getProfile())?.id
        await fetchDetail()
    }

    /// Pull-to-refresh / post-action reload: same fetch, no skeleton.
    func refresh() async {
        await fetchDetail()
    }

    private func fetchDetail() async {
        guard let detail = try? await groupRepository.getGroupDetail(groupId: groupId) else {
            return
        }
        groupName = detail.group.name
        members = detail.members
    }

    // MARK: - Admin actions

    /// Seed the rename field with the current name, ready for the rename prompt.
    func beginRename() {
        nameDraft = groupName
        errorMessage = nil
    }

    /// Rename the group (admin only). Aborts before any repository call if the
    /// draft is invalid, mirroring the API's 1–50 rule.
    func rename() async {
        guard isNameDraftValid else {
            errorMessage = "Please enter a name between 1 and 50 characters."
            return
        }

        errorMessage = nil
        do {
            let updated = try await groupRepository.updateGroupName(
                groupId: groupId, name: trimmedNameDraft
            )
            groupName = updated.name
        } catch {
            errorMessage = "Couldn't rename the group. Please try again."
        }
    }

    /// Remove a member (admin only). Their pints stay on the leaderboard as a
    /// former member (requirements §5.14) — that's server-side; here we just
    /// re-fetch so the row disappears.
    func removeMember(userId: UUID) async {
        errorMessage = nil
        do {
            try await groupRepository.removeMember(groupId: groupId, userId: userId)
            await fetchDetail()
        } catch {
            errorMessage = "Couldn't remove that member. Please try again."
        }
    }

    /// Promote a member to admin (admin only). Re-fetching also re-derives
    /// `leaveOutcome`, so promoting someone turns a `.promoteFirst` into a
    /// `.simple` leave without any extra bookkeeping.
    func promoteMember(userId: UUID) async {
        errorMessage = nil
        do {
            try await groupRepository.promoteMember(groupId: groupId, userId: userId)
            await fetchDetail()
        } catch {
            errorMessage = "Couldn't promote that member. Please try again."
        }
    }

    // MARK: - Leave

    /// Leave the group. Refuses outright when another admin must be promoted first
    /// — the view shows that prompt instead of a confirmation, but the guard keeps
    /// the rule in the model rather than relying on the screen to enforce it. On
    /// success the repository applies the Active_Group fallback, so the Home tab
    /// re-renders for free; `didLeave` pops this screen.
    func leave() async {
        guard leaveOutcome != .promoteFirst else {
            errorMessage = "Promote another member to admin before leaving this group."
            return
        }

        errorMessage = nil
        isLeaving = true
        defer { isLeaving = false }

        do {
            try await groupRepository.leaveGroup(groupId: groupId)
            didLeave = true
        } catch {
            errorMessage = "Couldn't leave the group. Please try again."
        }
    }
}
