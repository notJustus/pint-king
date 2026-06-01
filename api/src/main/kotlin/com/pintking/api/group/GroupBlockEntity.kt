package com.pintking.api.group

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(
    name = "group_blocks",
    uniqueConstraints = [UniqueConstraint(columnNames = ["group_id", "user_id"])]
)
class GroupBlockEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "group_id", nullable = false)
    val groupId: UUID,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @Column(name = "blocked_at", nullable = false, updatable = false)
    val blockedAt: Instant = Instant.now()
)
