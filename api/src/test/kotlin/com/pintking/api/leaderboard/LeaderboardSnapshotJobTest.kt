package com.pintking.api.leaderboard

import com.pintking.api.common.Periods
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.time.temporal.IsoFields

@SpringBootTest
class LeaderboardSnapshotJobTest(
    private val job: LeaderboardSnapshotJob,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository
) : DescribeSpec({

    beforeEach {
        leaderboardSnapshotRepository.deleteAll()
        pintLogRepository.deleteAll()
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(creator: UserEntity, code: String): GroupEntity {
        val group = groupRepository.save(GroupEntity(name = "The Pub", inviteCode = code, createdBy = creator.id!!))
        groupMemberRepository.save(
            GroupMemberEntity(userId = creator.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
        )
        return group
    }

    fun addMember(user: UserEntity, group: GroupEntity) {
        groupMemberRepository.save(
            GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
        )
    }

    fun seedPints(user: UserEntity, group: GroupEntity, count: Int, loggedAt: Instant) {
        repeat(count) {
            pintLogRepository.save(
                PintLogEntity(
                    userId = user.id!!,
                    groupId = group.id!!,
                    photoUrl = "pints/${user.id}/${group.id}/${java.util.UUID.randomUUID()}.jpg",
                    loggedAt = loggedAt
                )
            )
        }
    }

    // A timestamp that lands squarely inside the just-completed week / month. We pin it to the
    // period start + a day so the exact day the test runs never matters.
    val week = Periods.completedWeek()
    val month = Periods.completedMonth()
    val inLastWeek: Instant = week.from.plus(1, ChronoUnit.DAYS)
    val inLastMonth: Instant = month.from.plus(1, ChronoUnit.DAYS)

    // The expected ISO week key, computed independently of the production helper.
    val expectedWeekKey = week.from.atZone(ZoneOffset.UTC).toLocalDate().let {
        "%04d-W%02d".format(it.get(IsoFields.WEEK_BASED_YEAR), it.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR))
    }

    describe("LeaderboardSnapshotJob — weekly") {

        it("computes and stores the completed week's ranking for each group") {
            val alice = seedUser("snap_alice_01", "Alice")
            val bob = seedUser("snap_bob_01", "Bob")
            val group = seedGroup(alice, "SNAPAA01")
            addMember(bob, group)
            seedPints(alice, group, 2, inLastWeek)
            seedPints(bob, group, 5, inLastWeek)

            job.snapshotWeekly()

            val rows = leaderboardSnapshotRepository.findAll()
            rows.map { Triple(it.userId, it.rank, it.pintCount) }.shouldContainExactlyInAnyOrder(
                Triple(bob.id!!, 1, 5),
                Triple(alice.id!!, 2, 2)
            )
            rows.forEach {
                it.periodType shouldBe "week"
                it.periodKey shouldBe expectedWeekKey
            }
        }

        it("is idempotent — running twice stores no duplicate rows") {
            val alice = seedUser("snap_alice_02", "Alice")
            val group = seedGroup(alice, "SNAPAA02")
            seedPints(alice, group, 3, inLastWeek)

            job.snapshotWeekly()
            job.snapshotWeekly()

            leaderboardSnapshotRepository.findAll().size shouldBe 1
        }

        it("stores no rows for a group with members but no pints in the period") {
            val alice = seedUser("snap_alice_03", "Alice")
            val group = seedGroup(alice, "SNAPAA03")
            // Pints exist, but outside the completed week (this week).
            seedPints(alice, group, 4, Instant.now())

            job.snapshotWeekly()

            leaderboardSnapshotRepository.findAll().shouldContainExactlyInAnyOrder()
        }

        it("dense-ranks ties, matching what the leaderboard would show") {
            val alice = seedUser("snap_alice_04", "Alice")
            val bob = seedUser("snap_bob_04", "Bob")
            val carol = seedUser("snap_carol_04", "Carol")
            val group = seedGroup(alice, "SNAPAA04")
            addMember(bob, group)
            addMember(carol, group)
            seedPints(alice, group, 5, inLastWeek)
            seedPints(bob, group, 5, inLastWeek)
            seedPints(carol, group, 2, inLastWeek)

            job.snapshotWeekly()

            val ranks = leaderboardSnapshotRepository.findAll().associate { it.userId to it.rank }
            ranks[alice.id!!] shouldBe 1
            ranks[bob.id!!] shouldBe 1
            // Dense: after two tied at 1, the next distinct count is rank 2.
            ranks[carol.id!!] shouldBe 2
        }

        it("snapshots only current members, excluding former members") {
            val alice = seedUser("snap_alice_05", "Alice")
            val ghost = seedUser("snap_ghost_05", "Ghost")
            val group = seedGroup(alice, "SNAPAA05")
            seedPints(alice, group, 2, inLastWeek)
            // Ghost logged the most but has no membership row → former member, must not appear.
            seedPints(ghost, group, 9, inLastWeek)

            job.snapshotWeekly()

            val rows = leaderboardSnapshotRepository.findAll()
            rows.map { it.userId }.shouldContainExactlyInAnyOrder(alice.id!!)
            rows.single().rank shouldBe 1
        }
    }

    describe("LeaderboardSnapshotJob — monthly") {

        it("computes and stores the completed month's ranking") {
            val alice = seedUser("snap_alice_06", "Alice")
            val group = seedGroup(alice, "SNAPAA06")
            seedPints(alice, group, 3, inLastMonth)

            job.snapshotMonthly()

            val row = leaderboardSnapshotRepository.findAll().single()
            row.periodType shouldBe "month"
            row.rank shouldBe 1
            row.pintCount shouldBe 3
        }
    }
}) {
    companion object {
        private val postgis = DockerImageName.parse("postgis/postgis:16-3.4")
            .asCompatibleSubstituteFor("postgres")

        private val postgres = PostgreSQLContainer(postgis).apply { start() }

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }
}
