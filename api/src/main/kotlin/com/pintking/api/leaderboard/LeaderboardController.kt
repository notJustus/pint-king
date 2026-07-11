package com.pintking.api.leaderboard

import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/groups")
class LeaderboardController(
    private val leaderboardService: LeaderboardService
) {

    @GetMapping("/{id}/leaderboard")
    fun getLeaderboard(
        @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID,
        @RequestParam(value = "period", required = false) period: String?
    ): ResponseEntity<LeaderboardResponse> =
        ResponseEntity.ok(leaderboardService.getLeaderboard(userId, id, period))
}

data class LeaderboardResponse(
    val period: String,
    val entries: List<LeaderboardEntry>,
    val formerMembers: List<FormerMemberEntry>
)

// A ranked, active member. `delta` is null for all_time and when no prior snapshot exists.
data class LeaderboardEntry(
    val userId: UUID,
    val displayName: String,
    val avatarUrl: String?,
    val pintCount: Long,
    val rank: Int,
    val delta: Int?,
    val isCrown: Boolean
)

// A user with pints in this group but no current membership. Unranked, greyed out client-side.
data class FormerMemberEntry(
    val userId: UUID,
    val displayName: String,
    val avatarUrl: String?,
    val pintCount: Long
)
