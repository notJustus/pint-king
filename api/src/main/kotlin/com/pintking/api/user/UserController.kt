package com.pintking.api.user

import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/users")
class UserController(private val userService: UserService) {

    @GetMapping("/me")
    fun getMe(@AuthenticationPrincipal userId: UUID): ResponseEntity<UserProfileResponse> {
        return ResponseEntity.ok(userService.getProfile(userId))
    }

    @PatchMapping("/me")
    fun updateMe(
        @AuthenticationPrincipal userId: UUID,
        @RequestBody request: UpdateUserRequest
    ): ResponseEntity<UserProfileResponse> {
        return ResponseEntity.ok(userService.updateProfile(userId, request))
    }
}

data class UpdateUserRequest(
    val displayName: String? = null,
    val activeGroupId: UUID? = null
)

data class UserProfileResponse(
    val id: UUID,
    val displayName: String,
    val avatarUrl: String?,
    val activeGroupId: UUID?
)
