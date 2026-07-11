package com.pintking.api.group

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
class GroupController(
    private val groupService: GroupService
) {

    @PostMapping
    fun createGroup(
        @AuthenticationPrincipal userId: UUID,
        @RequestBody request: CreateGroupRequest
    ): ResponseEntity<GroupResponse> {
        val group = groupService.createGroup(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(group)
    }

    @PostMapping("/join")
    fun joinGroup(
        @AuthenticationPrincipal userId: UUID,
        @RequestBody request: JoinGroupRequest
    ): ResponseEntity<GroupResponse> {
        val group = groupService.joinGroup(userId, request)
        return ResponseEntity.ok(group)
    }

    @GetMapping
    fun listGroups(
        @AuthenticationPrincipal userId: UUID
    ): ResponseEntity<List<GroupResponse>> {
        return ResponseEntity.ok(groupService.listGroups(userId))
    }

    @GetMapping("/{id}")
    fun getGroup(
        @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<GroupDetailResponse> {
        return ResponseEntity.ok(groupService.getGroup(userId, id))
    }

    @PatchMapping("/{id}")
    fun updateGroup(
        @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: UpdateGroupRequest
    ): ResponseEntity<GroupResponse> {
        return ResponseEntity.ok(groupService.updateGroup(userId, id, request))
    }

    @DeleteMapping("/{id}/members/{userId}")
    fun removeMember(
        @AuthenticationPrincipal callerId: UUID,
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
