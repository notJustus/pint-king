package com.pintking.api.auth

import io.jsonwebtoken.Jwts
import java.security.KeyPairGenerator
import java.security.interfaces.RSAPrivateKey
import java.security.interfaces.RSAPublicKey
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.*

object TestAppleTokens {

    private val keyPair = KeyPairGenerator.getInstance("RSA").apply {
        initialize(2048)
    }.generateKeyPair()

    val publicKey: RSAPublicKey = keyPair.public as RSAPublicKey
    private val privateKey: RSAPrivateKey = keyPair.private as RSAPrivateKey

    const val KID = "test-kid-001"

    fun createValidToken(subject: String): String {
        val now = Instant.now()
        return Jwts.builder()
            .header().keyId(KID).and()
            .issuer("https://appleid.apple.com")
            .subject(subject)
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(1, ChronoUnit.HOURS)))
            .signWith(privateKey)
            .compact()
    }

    fun createExpiredToken(subject: String): String {
        val past = Instant.now().minus(2, ChronoUnit.HOURS)
        return Jwts.builder()
            .header().keyId(KID).and()
            .issuer("https://appleid.apple.com")
            .subject(subject)
            .issuedAt(Date.from(past.minus(1, ChronoUnit.HOURS)))
            .expiration(Date.from(past))
            .signWith(privateKey)
            .compact()
    }
}
