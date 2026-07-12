package com.pintking.api.property

import com.pintking.api.common.ValidationException
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.pint.PintService
import com.pintking.api.pint.UpdatePintRequest
import com.pintking.api.storage.S3Service
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.string
import io.kotest.property.arbitrary.of
import io.kotest.property.checkAll
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.util.Optional
import java.util.UUID

/**
 * Feature: pint-king, Property 18: Pint metadata validation.
 *
 * A note is accepted iff its trimmed length ≤ 280; a drink_type iff it is one of the five allowed
 * values. Both rules live in [PintService] (create's validateMetadata and updatePint share the
 * same constants), so we fuzz them through the update path with the repo mocked to return a pint
 * the caller owns — that isolates the validation from any DB or S3 concern.
 */
class PintMetadataValidationPropertyTest : DescribeSpec({

    val allowed = setOf("beer", "lager", "ale", "stout", "cider")
    val userId = UUID.randomUUID()
    val pintId = UUID.randomUUID()

    fun service(): PintService {
        val pintRepo = mock<PintLogRepository>()
        val s3 = mock<S3Service>()
        whenever(pintRepo.findById(pintId)).thenReturn(
            Optional.of(PintLogEntity(id = pintId, userId = userId, groupId = UUID.randomUUID(), photoUrl = "k"))
        )
        whenever(s3.generatePresignedUrl(any())).thenReturn("https://signed")
        return PintService(pintRepo, mock(), mock(), s3, mock())
    }

    // Notes of wildly varying length, straddling the 280 boundary; plus surrounding whitespace,
    // since the rule is on the *trimmed* length.
    val noteArb = Arb.string(0..400)

    // A mix of valid enum values and arbitrary junk strings.
    val drinkArb = Arb.of(allowed + setOf("", "whisky", "Beer", "BEER", "wine", "lager ", "  ale"))

    describe("Property 18: pint metadata validation") {

        it("accepts a note iff its trimmed length is at most 280") {
            checkAll(300, noteArb) { note ->
                val shouldPass = note.trim().length <= 280
                val svc = service()
                if (shouldPass) {
                    svc.updatePint(userId, pintId, UpdatePintRequest(note = note))
                } else {
                    val ex = shouldThrow<ValidationException> {
                        svc.updatePint(userId, pintId, UpdatePintRequest(note = note))
                    }
                    ex.fieldErrors.any { it.field == "note" } shouldBe true
                }
            }
        }

        it("accepts a drink_type iff it is one of beer/lager/ale/stout/cider") {
            checkAll(200, drinkArb) { drink ->
                val shouldPass = drink in allowed
                val svc = service()
                if (shouldPass) {
                    val result = svc.updatePint(userId, pintId, UpdatePintRequest(drinkType = drink))
                    result.drinkType shouldBe drink
                } else {
                    val ex = shouldThrow<ValidationException> {
                        svc.updatePint(userId, pintId, UpdatePintRequest(drinkType = drink))
                    }
                    ex.fieldErrors.any { it.field == "drinkType" } shouldBe true
                }
            }
        }
    }
})
