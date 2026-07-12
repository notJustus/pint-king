package com.pintking.api.property

import com.pintking.api.common.UnprocessableException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.pint.CreatePintMetadata
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.pint.PintService
import com.pintking.api.storage.S3CleanupDispatcher
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.boolean
import io.kotest.property.checkAll
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.mock.web.MockMultipartFile
import java.util.Optional
import java.util.UUID

/**
 * Feature: pint-king, Property 17: Pint creation integrity.
 *
 * Fuzzes the three integrity guarantees with S3 and the DB mocked so the two failure axes —
 * "is a photo present?" and "does S3 succeed?" — can be varied independently and deterministically:
 *  (a) a missing/empty photo is rejected (422) before anything else happens;
 *  (b) a created pint is stamped with the caller's id and their active_group_id;
 *  (c) no DB row is written unless the S3 upload succeeds first (S3-first, ADR-0001).
 *
 * Container-backed happy paths live in PintCreateTest; the deterministic ordering examples in
 * PintServiceOrderingTest. This test proves the contract holds across the combination space.
 */
class PintCreationIntegrityPropertyTest : DescribeSpec({

    val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0x00)

    describe("Property 17: pint creation integrity") {

        it("rejects a missing or empty photo with 422 and never touches S3 or the DB") {
            checkAll(100, Arb.boolean()) { emptyNotNull ->
                val pintRepo = mock<PintLogRepository>()
                val s3 = mock<S3Service>()
                val users = mock<UserRepository>()
                val dispatcher = mock<S3CleanupDispatcher>()
                val service = PintService(pintRepo, mock(), users, s3, dispatcher)

                val userId = UUID.randomUUID()
                whenever(users.findById(userId)).thenReturn(
                    Optional.of(UserEntity(id = userId, appleId = "a", displayName = "T", activeGroupId = UUID.randomUUID()))
                )

                // Either a null part or a present-but-empty part — both are "no photo".
                val photo = if (emptyNotNull) MockMultipartFile("photo", ByteArray(0)) else null

                shouldThrow<UnprocessableException> {
                    service.createPint(userId, photo, CreatePintMetadata())
                }
                verify(s3, never()).uploadPhoto(any(), any(), any())
                verify(pintRepo, never()).saveAndFlush(any<PintLogEntity>())
            }
        }

        it("inserts a DB row iff the S3 upload succeeds, always stamped with caller id + active group") {
            checkAll(200, Arb.boolean()) { s3Succeeds ->
                val pintRepo = mock<PintLogRepository>()
                val s3 = mock<S3Service>()
                val users = mock<UserRepository>()
                val dispatcher = mock<S3CleanupDispatcher>()
                val service = PintService(pintRepo, mock(), users, s3, dispatcher)

                val userId = UUID.randomUUID()
                val groupId = UUID.randomUUID()
                whenever(users.findById(userId)).thenReturn(
                    Optional.of(UserEntity(id = userId, appleId = "a", displayName = "T", activeGroupId = groupId))
                )

                val photoKey = "pints/$userId/$groupId/${UUID.randomUUID()}.jpg"
                if (s3Succeeds) {
                    whenever(s3.uploadPhoto(any(), any(), any())).thenReturn(photoKey)
                    // The real DB assigns the id; mirror that so toResponse()'s id!! is safe.
                    whenever(pintRepo.saveAndFlush(any<PintLogEntity>())).thenAnswer {
                        val e = it.arguments[0] as PintLogEntity
                        PintLogEntity(
                            id = UUID.randomUUID(), userId = e.userId, groupId = e.groupId,
                            photoUrl = e.photoUrl, note = e.note, drinkType = e.drinkType,
                            location = e.location, loggedAt = e.loggedAt
                        )
                    }
                    whenever(s3.generatePresignedUrl(any())).thenReturn("https://signed/$photoKey")

                    val response = service.createPint(
                        userId, MockMultipartFile("photo", "p.jpg", "image/jpeg", jpeg), CreatePintMetadata()
                    )

                    // (b) stamped with the caller and their active group.
                    response.userId shouldBe userId
                    response.groupId shouldBe groupId
                    verify(pintRepo, times(1)).saveAndFlush(any<PintLogEntity>())
                } else {
                    whenever(s3.uploadPhoto(any(), any(), any())).thenThrow(RuntimeException("S3 down"))

                    shouldThrow<RuntimeException> {
                        service.createPint(
                            userId, MockMultipartFile("photo", "p.jpg", "image/jpeg", jpeg), CreatePintMetadata()
                        )
                    }
                    // (c) upload failed → no DB row, nothing to clean up.
                    verify(pintRepo, never()).saveAndFlush(any<PintLogEntity>())
                    verify(dispatcher, never()).deleteObjects(any())
                }
            }
        }
    }
})
