package com.pintking.api.group

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(
    name = "group_members",
    uniqueConstraints = [UniqueConstraint(columnNames = ["user_id", "group_id"])]
)
class GroupMemberEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @Column(name = "group_id", nullable = false)
    val groupId: UUID,

    @Column(name = "role", nullable = false, length = 10)
    var role: String,

    @Column(name = "joined_at", nullable = false, updatable = false)
    val joinedAt: Instant = Instant.now()
) {
    companion object {
        const val ROLE_ADMIN = "admin"
        const val ROLE_MEMBER = "member"
    }
}
