package com.pintking.api.auth

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
