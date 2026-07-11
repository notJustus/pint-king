package com.pintking.api.pint

import com.pintking.api.common.BadRequestException
import com.pintking.api.common.FieldError
import com.pintking.api.common.ImageValidation
import com.pintking.api.common.NotFoundException
import com.pintking.api.common.UnprocessableException
import com.pintking.api.common.ValidationException
import com.pintking.api.storage.S3CleanupDispatcher
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserRepository
import org.locationtech.jts.geom.Coordinate
import org.locationtech.jts.geom.GeometryFactory
import org.locationtech.jts.geom.Point
import org.locationtech.jts.geom.PrecisionModel
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.util.UUID

@Service
class PintService(
    private val pintLogRepository: PintLogRepository,
    private val userRepository: UserRepository,
    private val s3Service: S3Service,
    private val s3CleanupDispatcher: S3CleanupDispatcher
) {

    companion object {
        private const val MAX_PHOTO_BYTES = 10 * 1024 * 1024
        private const val MAX_NOTE_LENGTH = 280
        val ALLOWED_DRINK_TYPES = setOf("beer", "lager", "ale", "stout", "cider")
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
