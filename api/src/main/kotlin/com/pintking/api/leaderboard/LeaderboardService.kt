package com.pintking.api.leaderboard

import com.pintking.api.common.FieldError
import com.pintking.api.common.ForbiddenException
import com.pintking.api.common.Periods
import com.pintking.api.common.ValidationException
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class LeaderboardService(
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository,
    private val userRepository: UserRepository,
    private val s3Service: S3Service
) {

    /**
     * GET /groups/{id}/leaderboard — current members ranked by pint count for the period,
     * with dense ties (Property 20), rank deltas from the previous period's snapshot
     * (Property 22, ADR-0005), and former members listed separately (Property 23).
     */
    @Transactional(readOnly = true)
    fun getLeaderboard(userId: UUID, groupId: UUID, period: String?): LeaderboardResponse {
        // Requirement 7.2 / Property 26: same stance as the feed — membership is checked
        // before anything is read, so a non-member and a non-existent group both get 403.
        groupMemberRepository.findByUserIdAndGroupId(userId, groupId)
            ?: throw ForbiddenException("You are not a member of this group")

        val resolvedPeriod = period ?: Periods.ALL_TIME
        if (resolvedPeriod !in Periods.ALLOWED) {
            throw ValidationException(
                listOf(FieldError("period", "Period must be one of ${Periods.ALLOWED.joinToString(", ")}"))
            )
        }

        // Pints-per-user for the period, aggregated in the DB (one row per user who logged).
        val from = Periods.lowerBound(resolvedPeriod)
        val counts = (
            if (from == null) pintLogRepository.countByUser(groupId)
            else pintLogRepository.countByUserSince(groupId, from)
            ).associate { it.userId to it.count }

        // Current members are the only ones who get ranked; a member with no pints this
        // period still appears with a count of 0 (Requirement 5.1).
        val memberIds = groupMemberRepository.findByGroupId(groupId).map { it.userId }.toSet()

        // A former member is someone with pints in this group but no current membership
        // (Property 23). They never affect active ranks and live in a separate section.
        val formerIds = counts.keys - memberIds

        // Batch-load every user we'll render so display name / avatar cost one query, not N.
        val users = userRepository.findAllById(memberIds + formerIds).associateBy { it.id!! }

        // Delta baseline: the previous completed period's final snapshot (null for all_time).
        val snapshotRanks = previousSnapshotRanks(groupId, resolvedPeriod)

        val entries = rankMembers(memberIds, counts, users, snapshotRanks)

        val formerMembers = formerIds
            .map { id ->
                val user = users[id]
                FormerMemberEntry(
                    userId = id,
                    displayName = user?.displayName ?: "",
                    avatarUrl = user?.avatarUrl?.let { s3Service.generatePresignedUrl(it) },
                    pintCount = counts[id] ?: 0
                )
            }
            .sortedByDescending { it.pintCount }

        return LeaderboardResponse(
            period = resolvedPeriod,
            entries = entries,
            formerMembers = formerMembers
        )
    }

    /**
     * Dense ranking (Property 20): members sorted by pint count descending, equal counts
     * share a rank, and the next distinct count is previous rank + 1 (not +tie-count).
     * Rank 1 wears the crown — all of it, if several tie at the top (Requirement 5.5).
     */
    private fun rankMembers(
        memberIds: Set<UUID>,
        counts: Map<UUID, Long>,
        users: Map<UUID, UserEntity>,
        snapshotRanks: Map<UUID, Int>?
    ): List<LeaderboardEntry> {
        val sorted = memberIds.sortedByDescending { counts[it] ?: 0 }

        var rank = 0
        var previousCount: Long? = null
        return sorted.map { id ->
            val count = counts[id] ?: 0
            if (count != previousCount) {
                rank++
                previousCount = count
            }
            val user = users[id]
            // Property 22: delta = previous snapshot rank − current rank. Positive = climbed.
            val delta = snapshotRanks?.get(id)?.let { it - rank }
            LeaderboardEntry(
                userId = id,
                displayName = user?.displayName ?: "",
                avatarUrl = user?.avatarUrl?.let { s3Service.generatePresignedUrl(it) },
                pintCount = count,
                rank = rank,
                delta = delta,
                isCrown = rank == 1
            )
        }
    }

    /** Map of userId → rank from the previous period's snapshot, or null for all_time. */
    private fun previousSnapshotRanks(groupId: UUID, period: String): Map<UUID, Int>? {
        val key = Periods.previousSnapshotKey(period) ?: return null
        return leaderboardSnapshotRepository
            .findByGroupIdAndPeriodTypeAndPeriodKey(groupId, key.periodType, key.periodKey)
            .associate { it.userId to it.rank }
    }
}
