package com.pintking.api.group

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface GroupRepository : JpaRepository<GroupEntity, UUID> {
    fun findByInviteCode(inviteCode: String): GroupEntity?
    fun findByCreatedBy(createdBy: UUID): List<GroupEntity>
    fun countByCreatedBy(createdBy: UUID): Long
    fun existsByInviteCode(inviteCode: String): Boolean
}
