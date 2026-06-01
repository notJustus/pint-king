package com.pintking.api.group

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(name = "groups")
class GroupEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "name", nullable = false, length = 50)
    var name: String,

    @Column(name = "invite_code", nullable = false, unique = true, length = 8)
    var inviteCode: String,

    @Column(name = "created_by", nullable = false)
    val createdBy: UUID,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: Instant = Instant.now()
)
