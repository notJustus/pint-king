package com.pintking.api.leaderboard

import jakarta.persistence.*
import java.time.Instant
import java.util.*

@Entity
@Table(
    name = "leaderboard_snapshots",
    uniqueConstraints = [UniqueConstraint(columnNames = ["group_id", "user_id", "period_type", "period_key"])]
)
class LeaderboardSnapshotEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "group_id", nullable = false)
    val groupId: UUID,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @Column(name = "period_type", nullable = false, length = 10)
    val periodType: String,

    @Column(name = "period_key", nullable = false, length = 10)
    val periodKey: String,

    @Column(name = "rank", nullable = false)
    val rank: Int,

    @Column(name = "pint_count", nullable = false)
    val pintCount: Int,

    @Column(name = "snapshot_at", nullable = false, updatable = false)
    val snapshotAt: Instant = Instant.now()
)
