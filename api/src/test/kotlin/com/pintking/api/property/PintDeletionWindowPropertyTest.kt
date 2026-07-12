package com.pintking.api.property

import com.pintking.api.common.BadRequestException
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.pint.PintService
import io.kotest.assertions.throwables.shouldNotThrowAny
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.property.Arb
import io.kotest.property.arbitrary.long
import io.kotest.property.checkAll
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.Instant
import java.util.Optional
import java.util.UUID

/**
 * Feature: pint-king, Property 19: Pint deletion time window.
 *
 * Deletion succeeds iff now is within 24h of `logged_at` (Property 19 / ADR uses an inclusive
 * boundary — `Duration > 24h` rejects, so exactly 24h is still allowed). We fuzz the age of the
 * pint around the boundary with the repo mocked so only the window logic is under test.
 *
 * deletePint registers an after-commit S3 cleanup on the success path, which needs an active
 * transaction synchronization; we open one manually so the success path completes cleanly and a
 * BadRequestException can only mean "outside the window", never a stray sync error.
 */
class PintDeletionWindowPropertyTest : DescribeSpec({

    val window = 24L * 3600 // seconds
    val userId = UUID.randomUUID()
    val pintId = UUID.randomUUID()

    fun serviceForPintAged(ageSeconds: Long): PintService {
        val pintRepo = mock<PintLogRepository>()
        whenever(pintRepo.findById(pintId)).thenReturn(
            Optional.of(
                PintLogEntity(
                    id = pintId,
                    userId = userId,
                    groupId = UUID.randomUUID(),
                    photoUrl = "k",
                    loggedAt = Instant.now().minusSeconds(ageSeconds)
                )
            )
        )
        whenever(pintRepo.delete(any())).thenAnswer { }
        return PintService(pintRepo, mock(), mock(), mock(), mock())
    }

    beforeEach { TransactionSynchronizationManager.initSynchronization() }
    afterEach { TransactionSynchronizationManager.clearSynchronization() }

    describe("Property 19: pint deletion time window") {

        it("succeeds iff the pint is at most 24h old, rejects with 400 once older") {
            // Ages from a bit in the "future" (clock skew) out to ~48h old.
            checkAll(300, Arb.long(-3600L, 2 * window)) { age ->
                // Guard against the exact-boundary flake: skip the razor's edge where the few
                // milliseconds spent building the mock could tip Duration over 24h either way.
                val nearBoundary = kotlin.math.abs(age - window) <= 2
                if (!nearBoundary) {
                    val svc = serviceForPintAged(age)
                    if (age <= window) {
                        shouldNotThrowAny { svc.deletePint(userId, pintId) }
                    } else {
                        shouldThrow<BadRequestException> { svc.deletePint(userId, pintId) }
                    }
                }
            }
        }
    }
})
