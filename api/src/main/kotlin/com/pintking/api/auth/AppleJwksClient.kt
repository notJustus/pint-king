package com.pintking.api.auth

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import org.springframework.stereotype.Component
import java.math.BigInteger
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.KeyFactory
import java.security.interfaces.RSAPublicKey
import java.security.spec.RSAPublicKeySpec
import java.util.*

@Component
open class AppleJwksClient {

    private val jwksUrl = "https://appleid.apple.com/auth/keys"
    private val httpClient = HttpClient.newHttpClient()
    private val objectMapper = jacksonObjectMapper()

    open fun getPublicKey(kid: String): RSAPublicKey? {
        val keys = fetchKeys()
        val key = keys.find { it["kid"] == kid } ?: return null

        val n = Base64.getUrlDecoder().decode(key["n"])
        val e = Base64.getUrlDecoder().decode(key["e"])

        val spec = RSAPublicKeySpec(
            BigInteger(1, n),
            BigInteger(1, e)
        )
        return KeyFactory.getInstance("RSA").generatePublic(spec) as RSAPublicKey
    }

    private fun fetchKeys(): List<Map<String, String>> {
        val request = HttpRequest.newBuilder()
            .uri(URI.create(jwksUrl))
            .GET()
            .build()

        val response = httpClient.send(request, HttpResponse.BodyHandlers.ofString())
        val body: Map<String, List<Map<String, String>>> = objectMapper.readValue(response.body())
        return body["keys"] ?: emptyList()
    }
}
