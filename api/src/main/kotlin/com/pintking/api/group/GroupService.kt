package com.pintking.api.group

import com.pintking.api.common.FieldError
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.UnprocessableException
import com.pintking.api.common.ValidationException
import com.pintking.api.user.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.SecureRandom
import java.util.UUID

@Service
class GroupService(
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val userRepository: UserRepository
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
