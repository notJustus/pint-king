package com.pintking.api.leaderboard

import java.util.UUID

/**
 * Dense ranking shared by the read endpoint (Task 25) and the snapshot job (Task 26), so the
 * two can never disagree on how a group's members rank (Property 20).
 *
 * Members are sorted by pint count descending; equal counts share a rank; the next distinct
 * count is previous rank + 1 (dense — `1, 1, 2`, not competition `1, 1, 3`). A member absent
 * from [counts] is treated as 0 (a current member who logged nothing this period).
 *
 * The rank of any member with pints is identical whether or not zero-pint members are included
 * in [userIds] — they always sort last — so the read endpoint can pass its full membership and
 * the job can pass only the loggers and both get the same ranks for the loggers.
 */
object DenseRanking {

    data class Ranked(val userId: UUID, val count: Long, val rank: Int)

    fun rank(userIds: Collection<UUID>, counts: Map<UUID, Long>): List<Ranked> {
        val sorted = userIds.sortedByDescending { counts[it] ?: 0 }

        var rank = 0
        var previousCount: Long? = null
        return sorted.map { id ->
            val count = counts[id] ?: 0
            if (count != previousCount) {
                rank++
                previousCount = count
            }
            Ranked(id, count, rank)
        }
    }
}
