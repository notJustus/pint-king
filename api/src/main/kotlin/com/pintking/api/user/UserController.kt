package com.pintking.api.user

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile
import java.util.UUID

@RestController
@RequestMapping("/users")
@Tag(name = "Users", description = "The signed-in user's own profile and avatar.")
class UserController(
    private val userService: UserService,
    private val accountService: AccountService
) {

    @GetMapping("/me")
    @Operation(summary = "Get my profile")
    fun getMe(@Parameter(hidden = true) @AuthenticationPrincipal userId: UUID): ResponseEntity<UserProfileResponse> {
        return ResponseEntity.ok(userService.getProfile(userId))
    }

    @PatchMapping("/me")
    @Operation(summary = "Update my profile", description = "Updates display name and/or active group; omitted fields are left unchanged.")
    fun updateMe(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @RequestBody request: UpdateUserRequest
    ): ResponseEntity<UserProfileResponse> {
        return ResponseEntity.ok(userService.updateProfile(userId, request))
    }

    @PostMapping("/me/avatar")
    @Operation(summary = "Upload avatar", description = "Uploads a new avatar image and returns the updated profile.")
    fun uploadAvatar(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @RequestParam("file") file: MultipartFile
    ): ResponseEntity<UserProfileResponse> {
        return ResponseEntity.ok(userService.updateAvatar(userId, file))
    }

    @DeleteMapping("/me")
    @Operation(summary = "Delete my account", description = "Deletes the account and cascades removal of the user's data.")
    fun deleteMe(@Parameter(hidden = true) @AuthenticationPrincipal userId: UUID): ResponseEntity<Void> {
        accountService.deleteAccount(userId)
        return ResponseEntity.noContent().build()
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
