package com.pintking.api.auth

import com.pintking.api.common.UnauthorizedException
import io.jsonwebtoken.Jwts
import org.springframework.stereotype.Component
import java.math.BigInteger
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.KeyFactory
import java.security.PublicKey
import java.security.spec.RSAPublicKeySpec
import java.util.*

@Component
class AppleTokenVerifier(private val appleJwksClient: AppleJwksClient) {

    fun verify(identityToken: String): String {
        try {
            val header = parseHeader(identityToken)
            val kid = header["kid"] ?: throw UnauthorizedException("Missing kid in token header")

            val publicKey = appleJwksClient.getPublicKey(kid)
                ?: throw UnauthorizedException("Unknown signing key")

            val claims = Jwts.parser()
                .verifyWith(publicKey)
                .requireIssuer("https://appleid.apple.com")
                .build()
                .parseSignedClaims(identityToken)

            return claims.payload.subject
                ?: throw UnauthorizedException("Missing subject in token")
        } catch (e: UnauthorizedException) {
            throw e
        } catch (e: Exception) {
            throw UnauthorizedException("Invalid identity token")
        }
    }

    private fun parseHeader(token: String): Map<String, String> {
        val headerPart = token.split(".").firstOrNull()
            ?: throw UnauthorizedException("Invalid token format")
        val decoded = Base64.getUrlDecoder().decode(headerPart)
        val json = com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
            .readValue(decoded, Map::class.java)
        @Suppress("UNCHECKED_CAST")
        return json as Map<String, String>
    }
}
