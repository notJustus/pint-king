package com.pintking.api.auth

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface RefreshTokenRepository : JpaRepository<RefreshTokenEntity, UUID> {
    fun findByTokenHash(tokenHash: String): RefreshTokenEntity?
    fun findByUserId(userId: UUID): List<RefreshTokenEntity>
    fun deleteByUserId(userId: UUID)
}
