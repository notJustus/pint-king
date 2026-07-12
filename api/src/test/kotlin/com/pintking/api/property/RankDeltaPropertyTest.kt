package com.pintking.api.property

import com.pintking.api.common.Periods
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.leaderboard.LeaderboardService
import com.pintking.api.leaderboard.LeaderboardSnapshotEntity
import com.pintking.api.leaderboard.LeaderboardSnapshotRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Feature: pint-king, Property 22: Rank delta computation.
 *
 * delta = previous-period snapshot rank − current rank (positive = climbed). Null when no snapshot
 * exists for that member, and always null for all_time. We drive the real [LeaderboardService]
 * against Postgres: seed a random current pint count and a random previous-week snapshot rank for
 * a member, ask for the this_week leaderboard, and check the reported delta equals our independently
 * computed `snapshotRank − currentRank`.
 */
@SpringBootTest
class RankDeltaPropertyTest(
    private val leaderboardService: LeaderboardService,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val snapshotRepository: LeaderboardSnapshotRepository
) : DescribeSpec({

    val seq = AtomicInteger(0)

    fun clean() {
        snapshotRepository.deleteAll()
        pintLogRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun newUser(name: String): UserEntity =
        userRepository.save(UserEntity(appleId = "delta_${seq.incrementAndGet()}", displayName = name))

    fun seedGroupWith(admin: UserEntity): GroupEntity {
        val g = groupRepository.save(
            GroupEntity(name = "G", inviteCode = "D%06d".format(seq.incrementAndGet()), createdBy = admin.id!!)
        )
        groupMemberRepository.save(GroupMemberEntity(userId = admin.id!!, groupId = g.id!!, role = GroupMemberEntity.ROLE_ADMIN))
        return g
    }

    fun seedPints(user: UserEntity, group: GroupEntity, count: Int) {
        repeat(count) {
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = "pints/${user.id}/${UUID.randomUUID()}.jpg")
            )
        }
    }

    beforeSpec { clean() }

    describe("Property 22: rank delta computation") {

        it("delta equals previous-snapshot-rank minus current-rank for this_week") {
            // The member is the sole member, so their current rank is deterministically 1 for any
            // positive pint count. We vary the previous snapshot rank and check delta = snapRank − 1.
            checkAll(150, Arb.int(1..3), Arb.int(1..10)) { pints, snapRank ->
                clean()
                val alice = newUser("Alice")
                val group = seedGroupWith(alice)
                seedPints(alice, group, pints)

                val key = Periods.previousSnapshotKey(Periods.THIS_WEEK)!!
                snapshotRepository.save(
                    LeaderboardSnapshotEntity(
                        groupId = group.id!!, userId = alice.id!!,
                        periodType = key.periodType, periodKey = key.periodKey,
                        rank = snapRank, pintCount = 1
                    )
                )

                val entry = leaderboardService.getLeaderboard(alice.id!!, group.id!!, Periods.THIS_WEEK)
                    .entries.single { it.userId == alice.id }

                entry.rank shouldBe 1
                entry.delta shouldBe (snapRank - 1)
            }
        }

        it("delta is null when no snapshot exists, and always null for all_time") {
            checkAll(100, Arb.int(1..5)) { pints ->
                clean()
                val alice = newUser("Alice")
                val group = seedGroupWith(alice)
                seedPints(alice, group, pints)

                // No snapshot → this_week delta is null.
                leaderboardService.getLeaderboard(alice.id!!, group.id!!, Periods.THIS_WEEK)
                    .entries.single { it.userId == alice.id }.delta.shouldBeNull()

                // Even with a snapshot present, all_time never reports a delta.
                val key = Periods.previousSnapshotKey(Periods.THIS_WEEK)!!
                snapshotRepository.save(
                    LeaderboardSnapshotEntity(
                        groupId = group.id!!, userId = alice.id!!,
                        periodType = key.periodType, periodKey = key.periodKey, rank = 4, pintCount = 1
                    )
                )
                leaderboardService.getLeaderboard(alice.id!!, group.id!!, Periods.ALL_TIME)
                    .entries.single { it.userId == alice.id }.delta.shouldBeNull()
            }
        }
    }
}) {
    companion object {
        private const val BUCKET = "pint-king-photos"

        private val postgis = DockerImageName.parse("postgis/postgis:16-3.4")
            .asCompatibleSubstituteFor("postgres")

        private val postgres = PostgreSQLContainer(postgis).apply { start() }

        private val localstack = LocalStackContainer(DockerImageName.parse("localstack/localstack:3.5"))
            .withServices(Service.S3)

        init {
            localstack.start()
            localstack.execInContainer("awslocal", "s3", "mb", "s3://$BUCKET")
        }

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
            registry.add("app.s3.endpoint") { localstack.getEndpointOverride(Service.S3).toString() }
            registry.add("app.s3.region") { localstack.region }
        }
    }
}
