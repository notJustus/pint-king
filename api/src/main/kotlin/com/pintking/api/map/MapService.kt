package com.pintking.api.map

import com.pintking.api.common.FieldError
import com.pintking.api.common.ForbiddenException
import com.pintking.api.common.ValidationException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class MapService(
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val userRepository: UserRepository,
    private val s3Service: S3Service
) {

    companion object {
        const val SCOPE_PERSONAL = "personal"
        const val SCOPE_GROUP = "group"
        val ALLOWED_SCOPES = setOf(SCOPE_PERSONAL, SCOPE_GROUP)
    }

    /**
     * GET /pints/map — pints with a location inside the viewport bounding box (Requirement 6.8,
     * Property 24). `personal` returns only the caller's pints; `group` returns every member's,
     * including former members (flagged). Pints without a location are excluded in the query.
     */
    @Transactional(readOnly = true)
    fun getMapPints(userId: UUID, request: MapQuery): List<MapPin> {
        // Requirement 7.2 / Property 26: same stance as the feed and leaderboard — membership is
        // checked before anything is read, so a non-member and a non-existent group both get 403.
        groupMemberRepository.findByUserIdAndGroupId(userId, request.groupId)
            ?: throw ForbiddenException("You are not a member of this group")

        val scope = request.scope ?: SCOPE_GROUP
        if (scope !in ALLOWED_SCOPES) {
            throw ValidationException(
                listOf(FieldError("scope", "Scope must be one of ${ALLOWED_SCOPES.joinToString(", ")}"))
            )
        }

        val pints = if (scope == SCOPE_PERSONAL) {
            pintLogRepository.findInBoundingBoxForUser(
                request.groupId, userId, request.swLat, request.swLng, request.neLat, request.neLng
            )
        } else {
            pintLogRepository.findInBoundingBox(
                request.groupId, request.swLat, request.swLng, request.neLat, request.neLng
            )
        }

        // A former member is an author with pints in this group but no current membership
        // (Property 23 / Requirement 6.6). Current members set the "who's still in" baseline.
        val memberIds = groupMemberRepository.findByGroupId(request.groupId).map { it.userId }.toSet()

        // Batch-load every author once so display name / avatar cost one query, not N.
        val authors = userRepository.findAllById(pints.map { it.userId }).associateBy { it.id!! }

        return pints.map { pint ->
            val author = authors[pint.userId]
            MapPin(
                id = pint.id!!,
                userId = pint.userId,
                displayName = author?.displayName ?: "",
                avatarUrl = author?.avatarUrl?.let { s3Service.generatePresignedUrl(it) },
                isFormerMember = pint.userId !in memberIds,
                photoUrl = s3Service.generatePresignedUrl(pint.photoUrl),
                note = pint.note,
                drinkType = pint.drinkType,
                latitude = pint.location!!.y,
                longitude = pint.location!!.x,
                loggedAt = pint.loggedAt
            )
        }
    }
}
