package com.pintking.api.auth

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(name = "refresh_tokens")
class RefreshTokenEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    val tokenHash: String,

    @Column(name = "used", nullable = false)
    var used: Boolean = false,

    @Column(name = "expires_at", nullable = false)
    val expiresAt: Instant,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now()
)
