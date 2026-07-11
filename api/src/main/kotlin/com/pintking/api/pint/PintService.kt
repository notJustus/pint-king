package com.pintking.api.pint

import com.pintking.api.common.BadRequestException
import com.pintking.api.common.FieldError
import com.pintking.api.common.ForbiddenException
import com.pintking.api.common.ImageValidation
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.PageResponse
import com.pintking.api.common.UnprocessableException
import com.pintking.api.common.ValidationException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.storage.S3CleanupDispatcher
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserRepository
import org.locationtech.jts.geom.Coordinate
import org.locationtech.jts.geom.GeometryFactory
import org.locationtech.jts.geom.Point
import org.locationtech.jts.geom.PrecisionModel
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.TemporalAdjusters
import java.time.DayOfWeek
import java.util.UUID

@Service
class PintService(
    private val pintLogRepository: PintLogRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val userRepository: UserRepository,
    private val s3Service: S3Service,
    private val s3CleanupDispatcher: S3CleanupDispatcher
) {

    companion object {
        private const val MAX_PHOTO_BYTES = 10 * 1024 * 1024
        private const val MAX_NOTE_LENGTH = 280
        val ALLOWED_DRINK_TYPES = setOf("beer", "lager", "ale", "stout", "cider")

        private const val DEFAULT_PAGE_SIZE = 20
        private const val MAX_PAGE_SIZE = 100
        val ALLOWED_PERIODS = setOf("all_time", "this_week", "this_month")
    }

    // 4326 = WGS84 lon/lat, matching the pint_logs.location column's SRID.
    private val geometryFactory = GeometryFactory(PrecisionModel(), 4326)

    @Transactional
    fun createPint(userId: UUID, photo: MultipartFile?, metadata: CreatePintMetadata): PintResponse {
        val bytes = validatePhoto(photo)
        val location = validateMetadata(metadata)

        // Property 17b: a pint always belongs to the author's current active group.
        // Requirement 4.2 disables logging client-side when there is none; the API
        // still guards it so a pint can never be created without a group.
        val user = userRepository.findById(userId).orElseThrow {
            NotFoundException("User not found")
        }
        val groupId = user.activeGroupId
            ?: throw BadRequestException("You must have an active group to log a pint")

        // S3-first (ADR-0001): the photo must land in S3 before any DB row references
        // it. An upload failure propagates as a 500 with no row created.
        val photoKey = s3Service.uploadPhoto(userId, groupId, bytes)

        // If the insert fails after a successful upload, the object is now orphaned.
        // Enqueue it for the cleanup job and surface a 500 — no half-written pint.
        // saveAndFlush forces the INSERT to run inside this try (UUID-generated ids
        // otherwise defer it to commit, past the catch) so constraint failures land here.
        val pint = try {
            pintLogRepository.saveAndFlush(
                PintLogEntity(
                    userId = userId,
                    groupId = groupId,
                    photoUrl = photoKey,
                    note = metadata.note?.trim()?.ifEmpty { null },
                    drinkType = metadata.drinkType,
                    location = location
                )
            )
        } catch (e: Exception) {
            s3CleanupDispatcher.deleteObjects(listOf(photoKey))
            throw e
        }

        return pint.toResponse()
    }

    /**
     * GET /pints — newest-first page of a group's pints, optionally bounded to the
     * current ISO week or calendar month (Requirements 5.3/5.4, Property 21).
     */
    @Transactional(readOnly = true)
    fun listPints(userId: UUID, groupId: UUID, period: String?, page: Int?, size: Int?): PageResponse<PintFeedItem> {
        // Requirement 26 / same stance as getGroup: membership is checked before
        // anything is read, so a non-member and a non-existent group both get 403.
        groupMemberRepository.findByUserIdAndGroupId(userId, groupId)
            ?: throw ForbiddenException("You are not a member of this group")

        val resolvedPeriod = period ?: "all_time"
        if (resolvedPeriod !in ALLOWED_PERIODS) {
            throw ValidationException(
                listOf(FieldError("period", "Period must be one of ${ALLOWED_PERIODS.joinToString(", ")}"))
            )
        }

        // page defaults to 0 and is clamped non-negative; size defaults to 20 and is
        // capped at 100 so a client can't request an unbounded page.
        val pageNumber = (page ?: 0).coerceAtLeast(0)
        val pageSize = (size ?: DEFAULT_PAGE_SIZE).coerceIn(1, MAX_PAGE_SIZE)
        val pageable = PageRequest.of(pageNumber, pageSize)

        val from = periodStart(resolvedPeriod)
        val pintPage = if (from == null) {
            pintLogRepository.findByGroupIdOrderByLoggedAtDesc(groupId, pageable)
        } else {
            pintLogRepository.findByGroupIdAndLoggedAtGreaterThanEqualOrderByLoggedAtDesc(groupId, from, pageable)
        }

        // Batch-load the authors for this page in one query to avoid an N+1.
        val authors = userRepository.findAllById(pintPage.content.map { it.userId })
            .associateBy { it.id!! }

        val items = pintPage.content.map { pint ->
            val author = authors[pint.userId]
            PintFeedItem(
                id = pint.id!!,
                userId = pint.userId,
                displayName = author?.displayName,
                avatarUrl = author?.avatarUrl?.let { s3Service.generatePresignedUrl(it) },
                groupId = pint.groupId,
                photoUrl = s3Service.generatePresignedUrl(pint.photoUrl),
                note = pint.note,
                drinkType = pint.drinkType,
                latitude = pint.location?.y,
                longitude = pint.location?.x,
                loggedAt = pint.loggedAt
            )
        }

        return PageResponse(
            data = items,
            page = pageNumber,
            size = pageSize,
            total = pintPage.totalElements
        )
    }

    /**
     * The inclusive lower bound for a period, or null for all_time (no bound).
     * Week is the current ISO week (Monday 00:00 UTC); month is the 1st at 00:00 UTC.
     */
    private fun periodStart(period: String): Instant? {
        val today = Instant.now().atZone(ZoneOffset.UTC).toLocalDate()
        return when (period) {
            "this_week" ->
                today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                    .atStartOfDay(ZoneOffset.UTC).toInstant()
            "this_month" ->
                today.withDayOfMonth(1).atStartOfDay(ZoneOffset.UTC).toInstant()
            else -> null
        }
    }

    private fun validatePhoto(photo: MultipartFile?): ByteArray {
        // Requirement 4.4: a photo is mandatory. A missing or empty part is a 422.
        if (photo == null || photo.isEmpty) {
            throw UnprocessableException("A photo is required")
        }
        val bytes = photo.bytes
        if (bytes.size > MAX_PHOTO_BYTES) {
            throw UnprocessableException("Photo must be 10 MB or smaller")
        }
        if (!ImageValidation.isJpegOrPng(bytes)) {
            throw UnprocessableException("Photo must be a JPEG or PNG image")
        }
        return bytes
    }

    /** Validates the optional metadata and returns the location point, if any. */
    private fun validateMetadata(metadata: CreatePintMetadata): Point? {
        val errors = mutableListOf<FieldError>()

        metadata.note?.let {
            if (it.trim().length > MAX_NOTE_LENGTH) {
                errors.add(FieldError("note", "Note must be at most $MAX_NOTE_LENGTH characters"))
            }
        }

        metadata.drinkType?.let {
            if (it !in ALLOWED_DRINK_TYPES) {
                errors.add(
                    FieldError("drinkType", "Drink type must be one of ${ALLOWED_DRINK_TYPES.joinToString(", ")}")
                )
            }
        }

        // Latitude and longitude are meaningless on their own — both or neither.
        if ((metadata.latitude == null) != (metadata.longitude == null)) {
            errors.add(FieldError("location", "Latitude and longitude must be provided together"))
        }

        if (errors.isNotEmpty()) {
            throw ValidationException(errors)
        }

        val lat = metadata.latitude ?: return null
        val lng = metadata.longitude!!
        // JTS Coordinate is (x, y) = (longitude, latitude).
        return geometryFactory.createPoint(Coordinate(lng, lat))
    }

    private fun PintLogEntity.toResponse(): PintResponse =
        PintResponse(
            id = id!!,
            userId = userId,
            groupId = groupId,
            photoUrl = s3Service.generatePresignedUrl(photoUrl),
            note = note,
            drinkType = drinkType,
            latitude = location?.y,
            longitude = location?.x,
            loggedAt = loggedAt
        )
}
