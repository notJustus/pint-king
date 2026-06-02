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
