package com.pintking.api.leaderboard

import com.pintking.api.common.Periods
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogRepository
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

/**
 * Freezes each group's final ranking at period boundaries into `leaderboard_snapshots`,
 * which the read endpoint (Task 25) reads back as the delta baseline (ADR-0005, ADR-0064).
 *
 * Two entry points, one per period:
 *  - [snapshotWeekly]  — Monday 00:05 UTC, snapshots the just-ended ISO week.
 *  - [snapshotMonthly] — 1st of month 00:05 UTC, snapshots the just-ended calendar month.
 *
 * The 00:05 offset gives Flyway/startup a moment past midnight and keeps the boundary maths
 * (which asks "what period ended just before now?") unambiguously on the new period's side.
 */
@Component
class LeaderboardSnapshotJob(
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 5 0 * * MON", zone = "UTC")
    fun snapshotWeekly() = snapshotAll(Periods.completedWeek())

    @Scheduled(cron = "0 5 0 1 * *", zone = "UTC")
    fun snapshotMonthly() = snapshotAll(Periods.completedMonth())

    private fun snapshotAll(period: Periods.CompletedPeriod) {
        log.info("Leaderboard snapshot job starting for {} {}", period.periodType, period.periodKey)
        var groups = 0
        var rows = 0
        for (group in groupRepository.findAll()) {
            try {
                rows += snapshotGroup(group.id!!, period)
                groups++
            } catch (e: Exception) {
                // Isolate a single group's failure so the rest of the run still completes.
                log.error("Snapshot failed for group {}; skipping", group.id, e)
            }
        }
        log.info("Leaderboard snapshot job done: {} rows across {} groups", rows, groups)
    }

    /**
     * Snapshots one group's completed-period ranking and returns the number of rows written.
     * `saveAll` writes the group's rows in one round-trip; the caller's try/catch isolates a
     * single group's failure from the rest of the run.
     */
    fun snapshotGroup(groupId: java.util.UUID, period: Periods.CompletedPeriod): Int {
        // Idempotent: the unique (group, user, period_type, period_key) constraint is the hard
        // guarantee; this pre-check just avoids a doomed insert on a re-run (Task 26 requirement).
        if (leaderboardSnapshotRepository.existsByGroupIdAndPeriodTypeAndPeriodKey(
                groupId, period.periodType, period.periodKey
            )
        ) {
            return 0
        }

        val counts = pintLogRepository
            .countByUserBetween(groupId, period.from, period.until)
            .associate { it.userId to it.count }

        // Only current members are ranked; a former member's retained pints (ADR-0004) never
        // enter a snapshot, matching what the leaderboard shows. Members with no pints in the
        // period are omitted — their absence doesn't change any logger's rank (dense ranking),
        // and "no pints anywhere → no rows" falls out for free.
        val memberIds = groupMemberRepository.findByGroupId(groupId).map { it.userId }.toSet()
        val loggers = counts.keys intersect memberIds
        if (loggers.isEmpty()) return 0

        val snapshots = DenseRanking.rank(loggers, counts).map { ranked ->
            LeaderboardSnapshotEntity(
                groupId = groupId,
                userId = ranked.userId,
                periodType = period.periodType,
                periodKey = period.periodKey,
                rank = ranked.rank,
                pintCount = ranked.count.toInt()
            )
        }
        leaderboardSnapshotRepository.saveAll(snapshots)
        return snapshots.size
    }
}
