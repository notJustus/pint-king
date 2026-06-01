package com.pintking.api.leaderboard

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface LeaderboardSnapshotRepository : JpaRepository<LeaderboardSnapshotEntity, UUID> {
    fun findByGroupIdAndPeriodTypeAndPeriodKey(
        groupId: UUID,
        periodType: String,
        periodKey: String
    ): List<LeaderboardSnapshotEntity>
}
