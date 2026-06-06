package com.pintking.api.auth

import io.kotest.core.spec.style.DescribeSpec
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.http.MediaType
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestAuthConfig::class)
class JwtAuthenticationFilterTest(
    private val mockMvc: MockMvc,
    private val jwtService: JwtService
) : DescribeSpec({

    describe("JWT security filter") {

        it("allows requests with a valid JWT to reach protected endpoints") {
            val userId = UUID.randomUUID()
            val jwt = jwtService.generateToken(userId)

            mockMvc.get("/test/paginated") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.data[0]") { value("item1") }
            }
        }

        it("returns 401 when no Authorization header is present") {
            mockMvc.get("/test/paginated")
                .andExpect {
                    status { isUnauthorized() }
                    jsonPath("$.status") { value(401) }
                    jsonPath("$.message") { value("Unauthorized") }
                }
        }

        it("returns 401 when the token has an invalid signature") {
            val fakeJwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.invalidsignature"

            mockMvc.get("/test/paginated") {
                header("Authorization", "Bearer $fakeJwt")
            }.andExpect {
                status { isUnauthorized() }
                jsonPath("$.status") { value(401) }
            }
        }

        it("returns 401 when Authorization header has wrong format") {
            mockMvc.get("/test/paginated") {
                header("Authorization", "Basic some-credentials")
            }.andExpect {
                status { isUnauthorized() }
                jsonPath("$.status") { value(401) }
            }
        }

        it("allows auth endpoints without a JWT") {
            val token = TestAppleTokens.createValidToken("filter_test_user")

            mockMvc.post("/auth/apple") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"identityToken": "$token"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.jwt") { isNotEmpty() }
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
