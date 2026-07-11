package com.pintking.api.group

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface GroupBlockRepository : JpaRepository<GroupBlockEntity, UUID> {
    fun findByGroupIdAndUserId(groupId: UUID, userId: UUID): GroupBlockEntity?
    fun deleteByUserId(userId: UUID)
    fun deleteByGroupId(groupId: UUID)
}
