package com.pintking.api.auth

import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldNotBeBlank
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.time.temporal.ChronoUnit

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestAuthConfig::class)
class AuthControllerTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val refreshTokenRepository: RefreshTokenRepository
) : DescribeSpec({

    beforeEach {
        refreshTokenRepository.deleteAll()
        userRepository.deleteAll()
    }

    describe("POST /auth/apple") {

        it("creates a new user and returns JWT + refresh token for a valid Apple token") {
            val token = TestAppleTokens.createValidToken("apple_user_001")

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.jwt") { isNotEmpty() }
                jsonPath("$.refreshToken") { isNotEmpty() }
                jsonPath("$.isNewUser") { value(true) }
            }

            val user = userRepository.findByAppleId("apple_user_001")
            user shouldNotBe null
            user!!.displayName shouldBe "User"
        }

        it("returns isNewUser=false for an existing user") {
            userRepository.save(UserEntity(appleId = "apple_user_002", displayName = "Existing"))

            val token = TestAppleTokens.createValidToken("apple_user_002")

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.isNewUser") { value(false) }
            }
        }

        it("returns the same user id when authenticating twice") {
            val token = TestAppleTokens.createValidToken("apple_user_003")

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
            }

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.isNewUser") { value(false) }
            }

            val users = userRepository.findAll().filter { it.appleId == "apple_user_003" }
            users.size shouldBe 1
        }

        it("stores refresh token hash in the database") {
            val token = TestAppleTokens.createValidToken("apple_user_004")

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
            }

            val user = userRepository.findByAppleId("apple_user_004")!!
            val tokens = refreshTokenRepository.findByUserId(user.id!!)
            tokens.size shouldBe 1
            tokens[0].tokenHash.shouldNotBeBlank()
            tokens[0].used shouldBe false
        }

        it("returns 401 for an invalid Apple token") {
            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "invalid.token.here"}"""
            }.andExpect {
                status { isUnauthorized() }
            }
        }

        it("returns 400 when identityToken is missing") {
            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{}"""
            }.andExpect {
                status { isBadRequest() }
            }
        }
    }

    describe("POST /auth/refresh") {

        fun authenticateAndGetRefreshToken(): String {
            val token = TestAppleTokens.createValidToken("refresh_test_user")
            val result = mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andReturn()

            val body = result.response.contentAsString
            return com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
                .readTree(body).get("refreshToken").asText()
        }

        it("returns new JWT and refresh token for a valid unused token") {
            val refreshToken = authenticateAndGetRefreshToken()

            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$refreshToken"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.jwt") { isNotEmpty() }
                jsonPath("$.refreshToken") { isNotEmpty() }
            }
        }

        it("marks the old token as used after rotation") {
            val refreshToken = authenticateAndGetRefreshToken()
            val tokenHash = RefreshTokenService.hash(refreshToken)

            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$refreshToken"}"""
            }.andExpect {
                status { isOk() }
            }

            val oldToken = refreshTokenRepository.findByTokenHash(tokenHash)!!
            oldToken.used shouldBe true
        }

        it("returns 401 for an expired token") {
            val user = userRepository.save(UserEntity(appleId = "expired_token_user", displayName = "Test"))
            val rawToken = "expired-test-token-value"
            refreshTokenRepository.save(
                RefreshTokenEntity(
                    userId = user.id!!,
                    tokenHash = RefreshTokenService.hash(rawToken),
                    expiresAt = Instant.now().minus(1, ChronoUnit.DAYS)
                )
            )

            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$rawToken"}"""
            }.andExpect {
                status { isUnauthorized() }
            }
        }

        it("returns 401 for a non-existent token") {
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "does-not-exist-in-db"}"""
            }.andExpect {
                status { isUnauthorized() }
            }
        }

        it("returns 401 and invalidates all user tokens on reuse") {
            val refreshToken = authenticateAndGetRefreshToken()

            // First use — should succeed
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$refreshToken"}"""
            }.andExpect {
                status { isOk() }
            }

            // Reuse the same token — should fail and wipe all tokens
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$refreshToken"}"""
            }.andExpect {
                status { isUnauthorized() }
            }

            val user = userRepository.findByAppleId("refresh_test_user")!!
            val remainingTokens = refreshTokenRepository.findByUserId(user.id!!)
            remainingTokens.size shouldBe 0
        }

        it("new token from rotation works for subsequent refresh") {
            val refreshToken = authenticateAndGetRefreshToken()

            val result = mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$refreshToken"}"""
            }.andReturn()

            val newRefreshToken = com.fasterxml.jackson.module.kotlin.jacksonObjectMapper()
                .readTree(result.response.contentAsString).get("refreshToken").asText()

            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$newRefreshToken"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.jwt") { isNotEmpty() }
                jsonPath("$.refreshToken") { isNotEmpty() }
            }
        }

        it("returns 400 when refreshToken is missing") {
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{}"""
            }.andExpect {
                status { isBadRequest() }
            }
        }
    }
}) {
    companion object {
        private val postgres = PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.4").asCompatibleSubstituteFor("postgres")
        ).apply { start() }

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }
}
