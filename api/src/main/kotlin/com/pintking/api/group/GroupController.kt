package com.pintking.api.group

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
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
}

data class CreateGroupRequest(
    val name: String? = null
)

data class GroupResponse(
    val id: UUID,
    val name: String,
    val inviteCode: String,
    val role: String,
    val memberCount: Long
)
