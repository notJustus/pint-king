package com.pintking.api.user

import com.pintking.api.common.FieldError
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.ValidationException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.storage.S3Service
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.UUID

@Service
class UserService(
    private val userRepository: UserRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val s3Service: S3Service
) {

    fun getProfile(userId: UUID): UserProfileResponse {
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }
        return user.toProfileResponse()
    }

    @Transactional
    fun updateProfile(userId: UUID, request: UpdateUserRequest): UserProfileResponse {
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }

        request.displayName?.let { name ->
            val trimmed = name.trim()
            if (trimmed.length !in 1..30) {
                throw ValidationException(
                    listOf(FieldError("displayName", "Display name must be between 1 and 30 characters"))
                )
            }
            user.displayName = trimmed
        }

        request.activeGroupId?.let { groupId ->
            val isMember = groupMemberRepository.findByUserIdAndGroupId(userId, groupId) != null
            if (!isMember) {
                throw ValidationException(
                    listOf(FieldError("activeGroupId", "You are not a member of this group"))
                )
            }
            user.activeGroupId = groupId
        }

        user.updatedAt = Instant.now()
        return user.toProfileResponse()
    }

    private fun UserEntity.toProfileResponse(): UserProfileResponse {
        return UserProfileResponse(
            id = id!!,
            displayName = displayName,
            avatarUrl = avatarUrl?.let { s3Service.generatePresignedUrl(it) },
            activeGroupId = activeGroupId
        )
    }
}
