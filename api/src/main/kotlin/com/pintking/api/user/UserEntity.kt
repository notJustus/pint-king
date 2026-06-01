package com.pintking.api.user

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(name = "users")
class UserEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "apple_id", nullable = false, unique = true)
    val appleId: String,

    @Column(name = "display_name", nullable = false, length = 30)
    var displayName: String,

    @Column(name = "avatar_url")
    var avatarUrl: String? = null,

    @Column(name = "active_group_id")
    var activeGroupId: UUID? = null,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: Instant = Instant.now()
)
