package com.pintking.api.auth

import com.pintking.api.common.UnauthorizedException
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.*

@Service
class RefreshTokenService(
    private val refreshTokenRepository: RefreshTokenRepository,
    @Value("\${app.refresh-token.expiry-days}") private val expiryDays: Long
) {

    private val secureRandom = SecureRandom()

    fun generateRefreshToken(userId: UUID): String {
        val tokenBytes = ByteArray(32)
        secureRandom.nextBytes(tokenBytes)
        val rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(tokenBytes)

        val entity = RefreshTokenEntity(
            userId = userId,
            tokenHash = hash(rawToken),
            expiresAt = Instant.now().plus(expiryDays, ChronoUnit.DAYS)
        )
        refreshTokenRepository.save(entity)

        return rawToken
    }

    @Transactional(noRollbackFor = [UnauthorizedException::class])
    fun rotateToken(rawToken: String): UUID {
        val tokenHash = hash(rawToken)
        val entity = refreshTokenRepository.findByTokenHash(tokenHash)
            ?: throw UnauthorizedException("Invalid refresh token")

        if (entity.expiresAt.isBefore(Instant.now())) {
            throw UnauthorizedException("Refresh token expired")
        }

        if (entity.used) {
            refreshTokenRepository.deleteByUserId(entity.userId)
            throw UnauthorizedException("Token reuse detected")
        }

        entity.used = true
        refreshTokenRepository.save(entity)

        return entity.userId
    }

    @Transactional
    fun deleteAllForUser(userId: UUID) {
        refreshTokenRepository.deleteByUserId(userId)
    }

    companion object {
        fun hash(token: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
            val hashBytes = digest.digest(token.toByteArray())
            return hashBytes.joinToString("") { "%02x".format(it) }
        }
    }
}
