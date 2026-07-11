package com.pintking.api.pint

import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.time.Instant
import java.util.*

interface PintLogRepository : JpaRepository<PintLogEntity, UUID> {
    fun findByGroupIdOrderByLoggedAtDesc(groupId: UUID): List<PintLogEntity>
    fun findByUserIdOrderByLoggedAtDesc(userId: UUID): List<PintLogEntity>
    fun findByUserId(userId: UUID): List<PintLogEntity>
    fun deleteByUserId(userId: UUID)
    fun deleteByGroupId(groupId: UUID)

    // Paginated listings (Task 22). all_time uses the first; week/month bound by logged_at.
    fun findByGroupIdOrderByLoggedAtDesc(groupId: UUID, pageable: Pageable): Page<PintLogEntity>
    fun findByGroupIdAndLoggedAtGreaterThanEqualOrderByLoggedAtDesc(
        groupId: UUID,
        from: Instant,
        pageable: Pageable
    ): Page<PintLogEntity>
}
