package com.pintking.api.auth

import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Primary
import java.security.interfaces.RSAPublicKey

@TestConfiguration
class TestAuthConfig {

    @Bean
    @Primary
    fun testAppleJwksClient(): AppleJwksClient {
        return object : AppleJwksClient() {
            override fun getPublicKey(kid: String): RSAPublicKey? {
                return if (kid == TestAppleTokens.KID) TestAppleTokens.publicKey else null
            }
        }
    }
}
