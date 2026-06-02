package com.pintking.api.auth

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.security.Keys
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.*
import javax.crypto.SecretKey

@Service
class JwtService(
    @Value("\${app.jwt.secret}") private val secret: String,
    @Value("\${app.jwt.expiry-hours}") private val expiryHours: Long
) {

    private val key: SecretKey = Keys.hmacShaKeyFor(secret.toByteArray())

    fun generateToken(userId: UUID): String {
        val now = Instant.now()
        return Jwts.builder()
            .subject(userId.toString())
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(expiryHours, ChronoUnit.HOURS)))
            .signWith(key)
            .compact()
    }

    fun validateToken(token: String): UUID? {
        return try {
            val claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
            UUID.fromString(claims.payload.subject)
        } catch (e: Exception) {
            null
        }
    }
}
