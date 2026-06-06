package com.pintking.api.user

import com.pintking.api.common.FieldError
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.UnprocessableException
import com.pintking.api.common.ValidationException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.storage.S3Service
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.time.Instant
import java.util.UUID

@Service
class UserService(
    private val userRepository: UserRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val s3Service: S3Service
) {

    companion object {
        private const val MAX_AVATAR_BYTES = 5 * 1024 * 1024
    }

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

    @Transactional
    fun updateAvatar(userId: UUID, file: MultipartFile): UserProfileResponse {
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }

        val bytes = file.bytes
        if (bytes.size > MAX_AVATAR_BYTES) {
            throw UnprocessableException("Avatar must be 5 MB or smaller")
        }
        if (!isJpeg(bytes) && !isPng(bytes)) {
            throw UnprocessableException("Avatar must be a JPEG or PNG image")
        }

        val previousKey = user.avatarUrl
        val newKey = s3Service.uploadAvatar(userId, bytes)
        user.avatarUrl = newKey
        user.updatedAt = Instant.now()

        // Best-effort cleanup of the replaced object. The new key is already
        // persisted, so a failure here only leaves an orphan for the cleanup job.
        if (previousKey != null) {
            s3Service.deleteObject(previousKey)
        }

        return user.toProfileResponse()
    }

    private fun isJpeg(bytes: ByteArray): Boolean =
        bytes.size >= 3 &&
            bytes[0] == 0xFF.toByte() &&
            bytes[1] == 0xD8.toByte() &&
            bytes[2] == 0xFF.toByte()

    private fun isPng(bytes: ByteArray): Boolean =
        bytes.size >= 8 &&
            bytes[0] == 0x89.toByte() &&
            bytes[1] == 0x50.toByte() && // P
            bytes[2] == 0x4E.toByte() && // N
            bytes[3] == 0x47.toByte() && // G
            bytes[4] == 0x0D.toByte() &&
            bytes[5] == 0x0A.toByte() &&
            bytes[6] == 0x1A.toByte() &&
            bytes[7] == 0x0A.toByte()

    private fun UserEntity.toProfileResponse(): UserProfileResponse {
        return UserProfileResponse(
            id = id!!,
            displayName = displayName,
            avatarUrl = avatarUrl?.let { s3Service.generatePresignedUrl(it) },
            activeGroupId = activeGroupId
        )
    }
}
