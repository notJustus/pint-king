package com.pintking.api.group

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/groups")
@Tag(name = "Groups", description = "Create and join groups, manage members and invite codes.")
class GroupController(
    private val groupService: GroupService
) {

    @PostMapping
    @Operation(summary = "Create a group", description = "Creates a group with a generated invite code; the caller becomes its admin.")
    fun createGroup(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @RequestBody request: CreateGroupRequest
    ): ResponseEntity<GroupResponse> {
        val group = groupService.createGroup(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(group)
    }

    @PostMapping("/join")
    @Operation(summary = "Join a group", description = "Joins the group identified by the invite code.")
    fun joinGroup(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @RequestBody request: JoinGroupRequest
    ): ResponseEntity<GroupResponse> {
        val group = groupService.joinGroup(userId, request)
        return ResponseEntity.ok(group)
    }

    @GetMapping
    @Operation(summary = "List my groups")
    fun listGroups(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID
    ): ResponseEntity<List<GroupResponse>> {
        return ResponseEntity.ok(groupService.listGroups(userId))
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get group detail", description = "Returns the group with its member list.")
    fun getGroup(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<GroupDetailResponse> {
        return ResponseEntity.ok(groupService.getGroup(userId, id))
    }

    @PatchMapping("/{id}")
    @Operation(summary = "Update group name", description = "Renames the group. Admin only.")
    fun updateGroup(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: UpdateGroupRequest
    ): ResponseEntity<GroupResponse> {
        return ResponseEntity.ok(groupService.updateGroup(userId, id, request))
    }

    @PostMapping("/{id}/members/{userId}/promote")
    @Operation(summary = "Promote a member to admin", description = "Idempotent. Admin only.")
    fun promoteMember(
        @Parameter(hidden = true) @AuthenticationPrincipal callerId: UUID,
        @PathVariable id: UUID,
        @PathVariable userId: UUID
    ): ResponseEntity<Void> {
        groupService.promoteMember(callerId, id, userId)
        return ResponseEntity.noContent().build()
    }

    @PostMapping("/{id}/invite-code/regenerate")
    @Operation(summary = "Regenerate invite code", description = "Issues a new invite code, invalidating the old one. Admin only.")
    fun regenerateInviteCode(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<GroupResponse> {
        return ResponseEntity.ok(groupService.regenerateInviteCode(userId, id))
    }

    @DeleteMapping("/{id}/members/{userId}")
    @Operation(summary = "Remove a member or leave", description = "Removes a member (admin) or leaves the group (self). Removal also blocks re-joining via the current code.")
    fun removeMember(
        @Parameter(hidden = true) @AuthenticationPrincipal callerId: UUID,
        @PathVariable id: UUID,
        @PathVariable userId: UUID
    ): ResponseEntity<Void> {
        groupService.removeMember(callerId, id, userId)
        return ResponseEntity.noContent().build()
    }
}

data class CreateGroupRequest(
    val name: String? = null
)

data class JoinGroupRequest(
    val inviteCode: String? = null
)

data class UpdateGroupRequest(
    val name: String? = null
)

data class GroupResponse(
    val id: UUID,
    val name: String,
    val inviteCode: String,
    val role: String,
    val memberCount: Long
)

data class GroupDetailResponse(
    val id: UUID,
    val name: String,
    val inviteCode: String,
    val role: String,
    val memberCount: Long,
    val members: List<GroupMemberResponse>
)

data class GroupMemberResponse(
    val userId: UUID,
    val displayName: String,
    val avatarUrl: String?,
    val role: String
)
