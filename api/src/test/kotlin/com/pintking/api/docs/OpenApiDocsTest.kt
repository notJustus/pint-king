package com.pintking.api.docs

import com.pintking.api.auth.TestAuthConfig
import io.kotest.core.spec.style.DescribeSpec
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

/**
 * Verifies the auto-generated OpenAPI document: the docs endpoints are reachable without a
 * token, every controller path is present, and the bearer-JWT security scheme is declared.
 * SpringDoc builds the document by scanning the live controller beans, so this only passes if
 * the whole web layer wires up — making it a smoke test for the generated spec.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestAuthConfig::class)
class OpenApiDocsTest(
    private val mockMvc: MockMvc
) : DescribeSpec({

    describe("GET /v3/api-docs") {

        it("is reachable without authentication and lists every endpoint path") {
            mockMvc.get("/v3/api-docs").andExpect {
                status { isOk() }
                jsonPath("$.info.title") { value("Pint King API") }
                // One assertion per registered path — if a controller mapping stops being
                // scanned, the corresponding check fails and names the missing route.
                jsonPath("$.paths./auth/apple") { exists() }
                jsonPath("$.paths./auth/refresh") { exists() }
                jsonPath("$.paths./auth/logout") { exists() }
                jsonPath("$.paths./users/me") { exists() }
                jsonPath("$.paths./users/me/avatar") { exists() }
                jsonPath("$.paths./groups") { exists() }
                jsonPath("$.paths./groups/join") { exists() }
                jsonPath("$.paths./groups/{id}") { exists() }
                jsonPath("$.paths./groups/{id}/members/{userId}") { exists() }
                jsonPath("$.paths./groups/{id}/members/{userId}/promote") { exists() }
                jsonPath("$.paths./groups/{id}/invite-code/regenerate") { exists() }
                jsonPath("$.paths./groups/{id}/leaderboard") { exists() }
                jsonPath("$.paths./pints") { exists() }
                jsonPath("$.paths./pints/{id}") { exists() }
                jsonPath("$.paths./pints/map") { exists() }
            }
        }

        it("declares the bearer-JWT security scheme") {
            mockMvc.get("/v3/api-docs").andExpect {
                status { isOk() }
                jsonPath("$.components.securitySchemes.bearerAuth.type") { value("http") }
                jsonPath("$.components.securitySchemes.bearerAuth.scheme") { value("bearer") }
                jsonPath("$.components.securitySchemes.bearerAuth.bearerFormat") { value("JWT") }
            }
        }

        it("leaves the public auth endpoints without a security requirement") {
            mockMvc.get("/v3/api-docs").andExpect {
                status { isOk() }
                // @SecurityRequirements renders as an empty security array on the operation.
                jsonPath("$.paths./auth/apple.post.security") { isEmpty() }
                jsonPath("$.paths./auth/refresh.post.security") { isEmpty() }
            }
        }
    }

    describe("Swagger UI") {

        it("serves the UI page without authentication") {
            mockMvc.get("/swagger-ui/index.html").andExpect {
                status { isOk() }
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
