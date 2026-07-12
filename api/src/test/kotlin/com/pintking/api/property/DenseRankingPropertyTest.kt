package com.pintking.api.property

import com.pintking.api.leaderboard.DenseRanking
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.comparables.shouldBeGreaterThanOrEqualTo
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll
import java.util.UUID

/**
 * Feature: pint-king, Property 20: Leaderboard ranking with dense ties.
 *
 * Fuzzes the pure [DenseRanking.rank] over random count distributions and asserts the three
 * invariants that define dense ranking, independently of how the function computes them:
 *  (a) results are ordered by count descending;
 *  (b) equal counts share a rank, unequal counts get different ranks;
 *  (c) the sequence of ranks is `1, 1, 2, 3, 3, 4, …` — starts at 1, only ever rises by 0 or 1
 *      (dense, never skipping a rank the way competition ranking's `1, 1, 3` does).
 */
class DenseRankingPropertyTest : DescribeSpec({

    // A distribution of N members each with a random pint count (0..30). Returns the member ids
    // and the count map DenseRanking consumes; some members are deliberately left out of the map
    // to exercise the "absent means 0" branch.
    val distribution = Arb.list(Arb.long(0L..30L), 0..12).map { counts ->
        val ids = List(counts.size) { UUID.randomUUID() }
        // Drop a third of the entries from the map so those members fall through to 0.
        val map = ids.zip(counts)
            .filterIndexed { i, _ -> i % 3 != 0 }
            .toMap()
        ids to map
    }

    describe("Property 20: dense ranking") {

        it("orders by count descending, ties share a rank, and ranks are dense") {
            checkAll(300, distribution) { (ids, counts) ->
                val ranked = DenseRanking.rank(ids, counts)

                // Every input member appears exactly once.
                ranked.map { it.userId }.toSet() shouldBe ids.toSet()
                ranked.size shouldBe ids.size

                // Each reported count matches the map (or 0 when absent).
                ranked.forEach { it.count shouldBe (counts[it.userId] ?: 0L) }

                // (a) descending by count.
                ranked.zipWithNext().forEach { (hi, lo) ->
                    hi.count shouldBeGreaterThanOrEqualTo lo.count
                }

                // (b)+(c) walk adjacent pairs: equal count ⇒ same rank; lower count ⇒ rank + 1.
                ranked.zipWithNext().forEach { (prev, next) ->
                    if (next.count == prev.count) {
                        next.rank shouldBe prev.rank
                    } else {
                        next.rank shouldBe prev.rank + 1
                    }
                }

                // First rank is 1 whenever anyone is ranked.
                ranked.firstOrNull()?.let { it.rank shouldBe 1 }
            }
        }

        it("assigns the same rank to two members iff they have the same count") {
            checkAll(200, distribution) { (ids, counts) ->
                val ranked = DenseRanking.rank(ids, counts)
                val byId = ranked.associateBy { it.userId }

                for (a in ids) {
                    for (b in ids) {
                        val sameCount = (counts[a] ?: 0L) == (counts[b] ?: 0L)
                        (byId.getValue(a).rank == byId.getValue(b).rank) shouldBe sameCount
                    }
                }
            }
        }

        it("gives loggers the same ranks whether or not zero-count members are included") {
            // The docstring guarantee the read endpoint (full membership) and the job
            // (only loggers) rely on: extra zero-count ids never change a logger's rank.
            checkAll(200, distribution) { (ids, counts) ->
                val loggers = ids.filter { (counts[it] ?: 0L) > 0L }

                val full = DenseRanking.rank(ids, counts).associate { it.userId to it.rank }
                val loggersOnly = DenseRanking.rank(loggers, counts).associate { it.userId to it.rank }

                loggers.map { full.getValue(it) } shouldContainExactly loggers.map { loggersOnly.getValue(it) }
            }
        }
    }
})
