package com.pintking.api.pint

import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.Instant
import java.util.*

/** A single row of the "pints per user" aggregation used by the leaderboard. */
interface UserPintCount {
    val userId: UUID
    val count: Long
}

interface PintLogRepository : JpaRepository<PintLogEntity, UUID> {
    fun findByGroupIdOrderByLoggedAtDesc(groupId: UUID): List<PintLogEntity>
    fun findByUserIdOrderByLoggedAtDesc(userId: UUID): List<PintLogEntity>
    fun findByUserId(userId: UUID): List<PintLogEntity>
    fun deleteByUserId(userId: UUID)
    fun deleteByGroupId(groupId: UUID)

    // Paginated listings (Task 22). all_time uses the first; week/month bound by logged_at.
    fun findByGroupIdOrderByLoggedAtDesc(groupId: UUID, pageable: Pageable): Page<PintLogEntity>
    fun findByGroupIdAndLoggedAtGreaterThanEqualOrderByLoggedAtDesc(
        groupId: UUID,
        from: Instant,
        pageable: Pageable
    ): Page<PintLogEntity>

    // Leaderboard (Task 25): pints per user for a group, grouped in the DB so a group with
    // thousands of pints returns one row per user, not the full log. `from` is the inclusive
    // period lower bound; null (via the all_time overload below) counts everything.
    @Query(
        """
        SELECT p.userId AS userId, COUNT(p) AS count
        FROM PintLogEntity p
        WHERE p.groupId = :groupId AND p.loggedAt >= :from
        GROUP BY p.userId
        """
    )
    fun countByUserSince(
        @Param("groupId") groupId: UUID,
        @Param("from") from: Instant
    ): List<UserPintCount>

    @Query(
        """
        SELECT p.userId AS userId, COUNT(p) AS count
        FROM PintLogEntity p
        WHERE p.groupId = :groupId
        GROUP BY p.userId
        """
    )
    fun countByUser(@Param("groupId") groupId: UUID): List<UserPintCount>

    // Snapshot job (Task 26): a *completed* period is bounded at both ends — [from, until) —
    // because we're freezing the past, not the still-open current period.
    @Query(
        """
        SELECT p.userId AS userId, COUNT(p) AS count
        FROM PintLogEntity p
        WHERE p.groupId = :groupId AND p.loggedAt >= :from AND p.loggedAt < :until
        GROUP BY p.userId
        """
    )
    fun countByUserBetween(
        @Param("groupId") groupId: UUID,
        @Param("from") from: Instant,
        @Param("until") until: Instant
    ): List<UserPintCount>

    // Map (Task 27): pints inside a lon/lat bounding box, native so we can use PostGIS.
    // ST_MakeEnvelope takes (xmin, ymin, xmax, ymax, srid) = (sw_lng, sw_lat, ne_lng, ne_lat, 4326);
    // ST_Within returns only points strictly inside the box. `location IS NULL` rows never match,
    // so pints without a location are excluded for free (Property 24c).
    @Query(
        nativeQuery = true,
        value = """
        SELECT * FROM pint_logs
        WHERE group_id = :groupId
          AND location IS NOT NULL
          AND ST_Within(location, ST_MakeEnvelope(:swLng, :swLat, :neLng, :neLat, 4326))
        """
    )
    fun findInBoundingBox(
        @Param("groupId") groupId: UUID,
        @Param("swLat") swLat: Double,
        @Param("swLng") swLng: Double,
        @Param("neLat") neLat: Double,
        @Param("neLng") neLng: Double
    ): List<PintLogEntity>

    // Personal scope: same box, further restricted to one author.
    @Query(
        nativeQuery = true,
        value = """
        SELECT * FROM pint_logs
        WHERE group_id = :groupId
          AND user_id = :userId
          AND location IS NOT NULL
          AND ST_Within(location, ST_MakeEnvelope(:swLng, :swLat, :neLng, :neLat, 4326))
        """
    )
    fun findInBoundingBoxForUser(
        @Param("groupId") groupId: UUID,
        @Param("userId") userId: UUID,
        @Param("swLat") swLat: Double,
        @Param("swLng") swLng: Double,
        @Param("neLat") neLat: Double,
        @Param("neLng") neLng: Double
    ): List<PintLogEntity>
}
