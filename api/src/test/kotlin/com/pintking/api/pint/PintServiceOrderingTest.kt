package com.pintking.api.pint

import com.pintking.api.storage.S3CleanupDispatcher
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.mock.web.MockMultipartFile
import java.util.Optional
import java.util.UUID

/**
 * Pure unit test of the S3-first ordering contract (ADR-0001), with the DB and S3
 * mocked so failures can be injected deterministically. The container-backed happy
 * paths live in PintCreateTest.
 */
class PintServiceOrderingTest : DescribeSpec({

    val userId = UUID.randomUUID()
    val groupId = UUID.randomUUID()
    val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0x00)

    fun activeUser() = UserEntity(id = userId, appleId = "apple_x", displayName = "T", activeGroupId = groupId)

    fun photo() = MockMultipartFile("photo", "p.jpg", "image/jpeg", jpeg)

    describe("S3-first ordering") {

        it("does not insert a DB row when the S3 upload fails") {
            val pintLogRepository = mock<PintLogRepository>()
            val userRepository = mock<UserRepository>()
            val s3Service = mock<S3Service>()
            val dispatcher = mock<S3CleanupDispatcher>()

            whenever(userRepository.findById(userId)).thenReturn(Optional.of(activeUser()))
            whenever(s3Service.uploadPhoto(any(), any(), any())).thenThrow(RuntimeException("S3 down"))

            val service = PintService(pintLogRepository, userRepository, s3Service, dispatcher)

            shouldThrow<RuntimeException> {
                service.createPint(userId, photo(), CreatePintMetadata())
            }

            // No upload success → nothing to insert, nothing to clean up.
            verify(pintLogRepository, never()).saveAndFlush(any())
            verify(dispatcher, never()).deleteObjects(any())
        }

        it("enqueues the orphaned object for cleanup when the DB insert fails after upload") {
            val photoKey = "pints/$userId/$groupId/${UUID.randomUUID()}.jpg"
            val pintLogRepository = mock<PintLogRepository>()
            val userRepository = mock<UserRepository>()
            val s3Service = mock<S3Service>()
            val dispatcher = mock<S3CleanupDispatcher>()

            whenever(userRepository.findById(userId)).thenReturn(Optional.of(activeUser()))
            whenever(s3Service.uploadPhoto(eq(userId), eq(groupId), any())).thenReturn(photoKey)
            whenever(pintLogRepository.saveAndFlush(any())).thenThrow(RuntimeException("DB down"))

            val service = PintService(pintLogRepository, userRepository, s3Service, dispatcher)

            shouldThrow<RuntimeException> {
                service.createPint(userId, photo(), CreatePintMetadata())
            }

            // The uploaded-but-unreferenced object must be handed to the cleanup job.
            verify(dispatcher).deleteObjects(listOf(photoKey))
        }
    }
})
