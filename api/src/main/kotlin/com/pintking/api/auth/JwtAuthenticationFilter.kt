package com.pintking.api.auth

import com.fasterxml.jackson.databind.ObjectMapper
import com.pintking.api.common.ErrorResponse
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
class JwtAuthenticationFilter(
    private val jwtService: JwtService,
    private val objectMapper: ObjectMapper
) : OncePerRequestFilter() {

    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        val path = request.requestURI
        return path in PUBLIC_PATHS ||
            path == "/actuator/health" ||
            PUBLIC_PREFIXES.any { path.startsWith(it) }
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val header = request.getHeader("Authorization")

        if (header == null || !header.startsWith("Bearer ")) {
            writeUnauthorized(response)
            return
        }

        val token = header.substring(7)
        val userId = jwtService.validateToken(token)

        if (userId == null) {
            writeUnauthorized(response)
            return
        }

        val authentication = UsernamePasswordAuthenticationToken(userId, null, emptyList())
        SecurityContextHolder.getContext().authentication = authentication
        filterChain.doFilter(request, response)
    }

    private fun writeUnauthorized(response: HttpServletResponse) {
        response.status = HttpStatus.UNAUTHORIZED.value()
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        response.writer.write(
            objectMapper.writeValueAsString(
                ErrorResponse(status = 401, message = "Unauthorized")
            )
        )
    }

    companion object {
        // Auth endpoints that must remain reachable without a JWT.
        // Everything else under /auth (e.g. /auth/logout) requires authentication.
        val PUBLIC_PATHS = setOf("/auth/apple", "/auth/refresh")

        // Prefixes served without a JWT: the OpenAPI document and Swagger UI assets.
        val PUBLIC_PREFIXES = listOf("/v3/api-docs", "/swagger-ui")
    }
}
