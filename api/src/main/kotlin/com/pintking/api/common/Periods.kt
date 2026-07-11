package com.pintking.api.common

import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.IsoFields
import java.time.temporal.TemporalAdjusters

/**
 * Shared time-period logic for the pint feed (Task 22) and the leaderboard (Task 25).
 *
 * Two flavours of the same "current week / current month" decision (ADR-0057):
 *  - [lowerBound] gives the inclusive start of the current period, used to filter which
 *    pints count toward the leaderboard / feed.
 *  - [previousSnapshotKey] gives the `(period_type, period_key)` of the *previous* completed
 *    period, used to look up the snapshot the rank delta is measured against (ADR-0005).
 *
 * All maths is UTC. The requirement text mentions the user's local timezone; MVP treats
 * "current week/month" as UTC and revisits if per-user timezones are added.
 */
object Periods {

    const val ALL_TIME = "all_time"
    const val THIS_WEEK = "this_week"
    const val THIS_MONTH = "this_month"

    val ALLOWED = setOf(ALL_TIME, THIS_WEEK, THIS_MONTH)

    /** A completed period's snapshot coordinates: `("week", "2024-W03")` or `("month", "2024-01")`. */
    data class SnapshotKey(val periodType: String, val periodKey: String)

    /**
     * The inclusive lower bound for a period, or null for all_time (no bound).
     * Week is the current ISO week (Monday 00:00 UTC); month is the 1st at 00:00 UTC.
     * Pints can't be logged in the future, so a lower bound alone is exact — no upper bound needed.
     */
    fun lowerBound(period: String, now: Instant = Instant.now()): Instant? {
        val today = now.atZone(ZoneOffset.UTC).toLocalDate()
        return when (period) {
            THIS_WEEK ->
                today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                    .atStartOfDay(ZoneOffset.UTC).toInstant()
            THIS_MONTH ->
                today.withDayOfMonth(1).atStartOfDay(ZoneOffset.UTC).toInstant()
            else -> null
        }
    }

    /**
     * The snapshot key for the period immediately before the current one, or null for all_time
     * (which has no delta). For this_week this is last ISO week; for this_month, last calendar month.
     */
    fun previousSnapshotKey(period: String, now: Instant = Instant.now()): SnapshotKey? {
        val today = now.atZone(ZoneOffset.UTC).toLocalDate()
        return when (period) {
            THIS_WEEK -> {
                val lastWeek = today.minusWeeks(1)
                val year = lastWeek.get(IsoFields.WEEK_BASED_YEAR)
                val week = lastWeek.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)
                SnapshotKey("week", "%04d-W%02d".format(year, week))
            }
            THIS_MONTH -> {
                val lastMonth = today.withDayOfMonth(1).minusMonths(1)
                SnapshotKey("month", "%04d-%02d".format(lastMonth.year, lastMonth.monthValue))
            }
            else -> null
        }
    }
}
