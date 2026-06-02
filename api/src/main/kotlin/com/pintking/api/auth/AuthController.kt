package com.pintking.api.auth

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/auth")
class AuthController(private val authService: AuthService) {

    @PostMapping("/apple")
    fun authenticateWithApple(@Valid @RequestBody request: AppleAuthRequest): ResponseEntity<AuthResponse> {
        val response = authService.authenticateWithApple(request.identityToken)
        return ResponseEntity.status(HttpStatus.OK).body(response)
    }

    @PostMapping("/refresh")
    fun refresh(@Valid @RequestBody request: RefreshRequest): ResponseEntity<TokenPair> {
        val tokenPair = authService.refresh(request.refreshToken)
        return ResponseEntity.ok(tokenPair)
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
