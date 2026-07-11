package com.pintking.api.group

import com.pintking.api.common.ConflictException
import com.pintking.api.common.FieldError
import com.pintking.api.common.ForbiddenException
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.UnprocessableException
import com.pintking.api.common.ValidationException
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.SecureRandom
import java.time.Instant
import java.util.UUID

@Service
class GroupService(
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val userRepository: UserRepository,
    private val s3Service: S3Service
) {

    companion object {
        private const val MAX_GROUPS_PER_USER = 99
        private const val INVITE_CODE_LENGTH = 8
        private const val INVITE_CODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        // Bounded so a saturated code space (astronomically unlikely) fails loudly
        // rather than looping forever.
        private const val INVITE_CODE_MAX_ATTEMPTS = 10
    }

    private val random = SecureRandom()

    @Transactional
    fun createGroup(userId: UUID, request: CreateGroupRequest): GroupResponse {
        val name = request.name?.trim().orEmpty()
        if (name.length !in 1..50) {
            throw ValidationException(
                listOf(FieldError("name", "Group name must be between 1 and 50 characters"))
            )
        }

        if (groupRepository.countByCreatedBy(userId) >= MAX_GROUPS_PER_USER) {
            throw UnprocessableException("You have reached the limit of $MAX_GROUPS_PER_USER groups")
        }

        val group = groupRepository.save(
            GroupEntity(
                name = name,
                inviteCode = generateUniqueInviteCode(),
                createdBy = userId
            )
        )

        groupMemberRepository.save(
            GroupMemberEntity(
                userId = userId,
                groupId = group.id!!,
                role = GroupMemberEntity.ROLE_ADMIN
            )
        )

        // Requirement 3.22: a user's first group becomes their active group.
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }
        if (user.activeGroupId == null) {
            user.activeGroupId = group.id
        }

        return GroupResponse(
            id = group.id!!,
            name = group.name,
            inviteCode = group.inviteCode,
            role = GroupMemberEntity.ROLE_ADMIN,
            memberCount = groupMemberRepository.countByGroupId(group.id!!)
        )
    }

    @Transactional
    fun joinGroup(userId: UUID, request: JoinGroupRequest): GroupResponse {
        val inviteCode = request.inviteCode?.trim().orEmpty()

        // Requirement 3.7: an unknown code is a 404, not a validation error.
        val group = groupRepository.findByInviteCode(inviteCode)
            ?: throw NotFoundException("Group not found")

        // Requirement 3.8: already a member → 409.
        if (groupMemberRepository.findByUserIdAndGroupId(userId, group.id!!) != null) {
            throw ConflictException("You are already a member of this group")
        }

        // Requirement 3.9: a previously-removed member is blocked → 403.
        if (groupBlockRepository.findByGroupIdAndUserId(group.id!!, userId) != null) {
            throw ForbiddenException("You have been removed from this group")
        }

        groupMemberRepository.save(
            GroupMemberEntity(
                userId = userId,
                groupId = group.id!!,
                role = GroupMemberEntity.ROLE_MEMBER
            )
        )

        // Requirement 3.22: joining your first group sets it as active.
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }
        if (user.activeGroupId == null) {
            user.activeGroupId = group.id
        }

        return GroupResponse(
            id = group.id!!,
            name = group.name,
            inviteCode = group.inviteCode,
            role = GroupMemberEntity.ROLE_MEMBER,
            memberCount = groupMemberRepository.countByGroupId(group.id!!)
        )
    }

    @Transactional
    fun updateGroup(userId: UUID, groupId: UUID, request: UpdateGroupRequest): GroupResponse {
        val name = request.name?.trim().orEmpty()
        if (name.length !in 1..50) {
            throw ValidationException(
                listOf(FieldError("name", "Group name must be between 1 and 50 characters"))
            )
        }

        // Requirement 10.3: only a Group_Admin may rename the group. A non-member
        // and a non-admin member are both rejected with 403, and — as with getGroup —
        // resolving membership before the group means a non-existent group is
        // indistinguishable from one the caller can't touch.
        val membership = groupMemberRepository.findByUserIdAndGroupId(userId, groupId)
        if (membership == null || membership.role != GroupMemberEntity.ROLE_ADMIN) {
            throw ForbiddenException("Only a group admin can update the group")
        }

        val group = groupRepository.findById(groupId).orElseThrow {
            NotFoundException("Group not found")
        }
        group.name = name
        group.updatedAt = Instant.now()

        return GroupResponse(
            id = group.id!!,
            name = group.name,
            inviteCode = group.inviteCode,
            role = membership.role,
            memberCount = groupMemberRepository.countByGroupId(group.id!!)
        )
    }

    @Transactional(readOnly = true)
    fun listGroups(userId: UUID): List<GroupResponse> {
        return groupMemberRepository.findByUserId(userId).map { membership ->
            val group = groupRepository.findById(membership.groupId).orElseThrow {
                NotFoundException("Group not found")
            }
            GroupResponse(
                id = group.id!!,
                name = group.name,
                inviteCode = group.inviteCode,
                role = membership.role,
                memberCount = groupMemberRepository.countByGroupId(group.id!!)
            )
        }
    }

    @Transactional(readOnly = true)
    fun getGroup(userId: UUID, groupId: UUID): GroupDetailResponse {
        // Requirement 7.2: reading a group you don't belong to is 403, not 404 —
        // membership is checked before the group is even resolved so a
        // non-existent group looks identical to one you simply can't see.
        val membership = groupMemberRepository.findByUserIdAndGroupId(userId, groupId)
            ?: throw ForbiddenException("You are not a member of this group")

        val group = groupRepository.findById(groupId).orElseThrow {
            NotFoundException("Group not found")
        }

        val members = groupMemberRepository.findByGroupId(groupId).map { member ->
            val user = userRepository.findById(member.userId).orElseThrow {
                NotFoundException("User not found")
            }
            GroupMemberResponse(
                userId = user.id!!,
                displayName = user.displayName,
                avatarUrl = user.avatarUrl?.let { s3Service.generatePresignedUrl(it) },
                role = member.role
            )
        }

        return GroupDetailResponse(
            id = group.id!!,
            name = group.name,
            inviteCode = group.inviteCode,
            role = membership.role,
            memberCount = members.size.toLong(),
            members = members
        )
    }

    private fun generateUniqueInviteCode(): String {
        repeat(INVITE_CODE_MAX_ATTEMPTS) {
            val code = (1..INVITE_CODE_LENGTH)
                .map { INVITE_CODE_ALPHABET[random.nextInt(INVITE_CODE_ALPHABET.length)] }
                .joinToString("")
            if (!groupRepository.existsByInviteCode(code)) {
                return code
            }
        }
        throw IllegalStateException("Unable to generate a unique invite code")
    }
}
