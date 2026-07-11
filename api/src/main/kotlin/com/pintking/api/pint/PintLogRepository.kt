package com.pintking.api.pint

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface PintLogRepository : JpaRepository<PintLogEntity, UUID> {
    fun findByGroupIdOrderByLoggedAtDesc(groupId: UUID): List<PintLogEntity>
    fun findByUserIdOrderByLoggedAtDesc(userId: UUID): List<PintLogEntity>
    fun findByUserId(userId: UUID): List<PintLogEntity>
    fun deleteByUserId(userId: UUID)
    fun deleteByGroupId(groupId: UUID)
}
