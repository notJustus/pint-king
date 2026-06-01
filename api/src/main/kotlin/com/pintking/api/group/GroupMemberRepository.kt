package com.pintking.api.group

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface GroupMemberRepository : JpaRepository<GroupMemberEntity, UUID> {
    fun findByUserIdAndGroupId(userId: UUID, groupId: UUID): GroupMemberEntity?
    fun findByUserId(userId: UUID): List<GroupMemberEntity>
    fun findByGroupId(groupId: UUID): List<GroupMemberEntity>
}
