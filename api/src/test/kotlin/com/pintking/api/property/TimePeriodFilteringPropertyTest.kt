package com.pintking.api.property

import com.pintking.api.common.Periods
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.instant
import io.kotest.property.arbitrary.long
import io.kotest.property.checkAll
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.TemporalAdjusters

/**
 * Feature: pint-king, Property 21: Time-period filtering correctness.
 *
 * The leaderboard and feed both reduce "this week / this month" to a single [Periods.lowerBound]
 * instant and count pints with `logged_at >= lowerBound` (the DB query does the comparison, and
 * pints can't be logged in the future so no upper bound is needed — see Periods' docstring). So
 * the property to fuzz is: for a random "now" and a random pint timestamp, `t >= lowerBound(now)`
 * agrees with an *independent* calendar computation of whether `t` is in the current ISO week /
 * calendar month, and all_time has no bound.
 */
class TimePeriodFilteringPropertyTest : DescribeSpec({

    // Random instants across ~a century, and offsets up to ±120 days from "now".
    val nowArb = Arb.instant(Instant.parse("2000-01-01T00:00:00Z"), Instant.parse("2100-01-01T00:00:00Z"))
    val offsetSeconds = Arb.long(-120L * 24 * 3600, 120L * 24 * 3600)

    describe("Property 21: time-period filtering") {

        it("all_time has no lower bound") {
            checkAll(200, nowArb) { now ->
                Periods.lowerBound(Periods.ALL_TIME, now).shouldBeNull()
            }
        }

        it("this_week includes a timestamp iff it falls in the current ISO week (Mon 00:00 UTC)") {
            checkAll(300, nowArb, offsetSeconds) { now, off ->
                val t = now.plusSeconds(off)
                val bound = Periods.lowerBound(Periods.THIS_WEEK, now)!!

                // Independent oracle: start of the ISO week (Monday 00:00 UTC) containing `now`.
                val expectedStart = now.atZone(ZoneOffset.UTC).toLocalDate()
                    .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                    .atStartOfDay(ZoneOffset.UTC).toInstant()

                bound shouldBe expectedStart
                (!t.isBefore(bound)) shouldBe (!t.isBefore(expectedStart))
            }
        }

        it("this_month includes a timestamp iff it falls in the current calendar month (1st 00:00 UTC)") {
            checkAll(300, nowArb, offsetSeconds) { now, off ->
                val t = now.plusSeconds(off)
                val bound = Periods.lowerBound(Periods.THIS_MONTH, now)!!

                // Independent oracle: the 1st of `now`'s month at 00:00 UTC.
                val expectedStart = now.atZone(ZoneOffset.UTC).toLocalDate()
                    .withDayOfMonth(1)
                    .atStartOfDay(ZoneOffset.UTC).toInstant()

                bound shouldBe expectedStart
                (!t.isBefore(bound)) shouldBe (!t.isBefore(expectedStart))
            }
        }

        it("the completed week's [from, until) abuts the current week's lower bound exactly") {
            // The snapshot job freezes the *previous* period; its `until` must be the current
            // period's lower bound so the two helpers can never disagree on the boundary.
            checkAll(200, nowArb) { now ->
                val completed = Periods.completedWeek(now)
                completed.until shouldBe Periods.lowerBound(Periods.THIS_WEEK, now)!!
                // The window is exactly seven days long.
                completed.from shouldBe completed.until.minusSeconds(7L * 24 * 3600)
            }
        }
    }
})
