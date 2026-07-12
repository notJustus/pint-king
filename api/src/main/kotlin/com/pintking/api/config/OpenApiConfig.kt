package com.pintking.api.config

import io.swagger.v3.oas.models.Components
import io.swagger.v3.oas.models.OpenAPI
import io.swagger.v3.oas.models.info.Info
import io.swagger.v3.oas.models.security.SecurityRequirement
import io.swagger.v3.oas.models.security.SecurityScheme
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

/**
 * Describes the generated OpenAPI document. SpringDoc scans the controllers for paths and
 * infers request/response schemas from the Kotlin DTOs; this bean supplies the metadata that
 * can't be inferred — the API title/version and the bearer-JWT security scheme.
 *
 * The security scheme is declared once here and applied globally as a requirement, so every
 * operation renders with an authorize lock in Swagger UI. The two genuinely public endpoints
 * (`/auth/apple`, `/auth/refresh`) opt out per-operation with `@SecurityRequirements` (empty).
 */
@Configuration
class OpenApiConfig {

    @Bean
    fun pintKingOpenApi(): OpenAPI {
        val bearerScheme = SecurityScheme()
            .type(SecurityScheme.Type.HTTP)
            .scheme("bearer")
            .bearerFormat("JWT")

        return OpenAPI()
            .info(
                Info()
                    .title("Pint King API")
                    .version("v1")
                    .description("Social beer tracking: log pints, compete on group leaderboards, view pints on a map.")
            )
            .components(Components().addSecuritySchemes(BEARER_SCHEME_NAME, bearerScheme))
            .addSecurityItem(SecurityRequirement().addList(BEARER_SCHEME_NAME))
    }

    companion object {
        const val BEARER_SCHEME_NAME = "bearerAuth"
    }
}
