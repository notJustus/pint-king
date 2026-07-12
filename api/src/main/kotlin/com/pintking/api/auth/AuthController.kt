package com.pintking.api.auth

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.security.SecurityRequirements
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/auth")
@Tag(name = "Auth", description = "Sign in with Apple, refresh tokens, and log out.")
class AuthController(private val authService: AuthService) {

    @PostMapping("/apple")
    @SecurityRequirements // public: exchanges an Apple identity token for our own tokens
    @Operation(summary = "Sign in with Apple", description = "Verifies the Apple identity token and returns a JWT + refresh token, creating the user on first sign-in.")
    fun authenticateWithApple(@Valid @RequestBody request: AppleAuthRequest): ResponseEntity<AuthResponse> {
        val response = authService.authenticateWithApple(request.identityToken)
        return ResponseEntity.status(HttpStatus.OK).body(response)
    }

    @PostMapping("/refresh")
    @SecurityRequirements // public: authenticates via the refresh token in the body, not a JWT
    @Operation(summary = "Refresh tokens", description = "Rotates the refresh token and issues a fresh JWT + refresh token pair.")
    fun refresh(@Valid @RequestBody request: RefreshRequest): ResponseEntity<TokenPair> {
        val tokenPair = authService.refresh(request.refreshToken)
        return ResponseEntity.ok(tokenPair)
    }

    @PostMapping("/logout")
    @Operation(summary = "Log out", description = "Revokes the caller's refresh tokens.")
    fun logout(@AuthenticationPrincipal userId: UUID): ResponseEntity<Void> {
        authService.logout(userId)
        return ResponseEntity.noContent().build()
    }
}

data class AppleAuthRequest(
    @field:NotBlank(message = "Identity token is required")
    val identityToken: String
)

data class RefreshRequest(
    @field:NotBlank(message = "Refresh token is required")
    val refreshToken: String
)

data class AuthResponse(
    val jwt: String,
    val refreshToken: String,
    val isNewUser: Boolean
)

data class TokenPair(
    val jwt: String,
    val refreshToken: String
)
