package com.pintking.api.leaderboard

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.time.temporal.IsoFields

@SpringBootTest
@AutoConfigureMockMvc
class LeaderboardTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        leaderboardSnapshotRepository.deleteAll()
        pintLogRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
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

    fun seedPints(user: UserEntity, group: GroupEntity, count: Int, loggedAt: Instant = Instant.now()) {
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

    describe("GET /groups/{id}/leaderboard") {

        it("ranks members in descending order of pint count") {
            val alice = seedUser("lb_alice_01", "Alice")
            val bob = seedUser("lb_bob_01", "Bob")
            val group = seedGroup(alice, "LBAAAA01")
            addMember(bob, group)
            seedPints(alice, group, 2)
            seedPints(bob, group, 5)
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries.length()") { value(2) }
                jsonPath("$.entries[0].displayName") { value("Bob") }
                jsonPath("$.entries[0].pintCount") { value(5) }
                jsonPath("$.entries[0].rank") { value(1) }
                jsonPath("$.entries[0].isCrown") { value(true) }
                jsonPath("$.entries[1].displayName") { value("Alice") }
                jsonPath("$.entries[1].rank") { value(2) }
                jsonPath("$.entries[1].isCrown") { value(false) }
            }
        }

        it("includes members with zero pints, ranked last") {
            val alice = seedUser("lb_alice_02", "Alice")
            val bob = seedUser("lb_bob_02", "Bob")
            val group = seedGroup(alice, "LBAAAA02")
            addMember(bob, group)
            seedPints(alice, group, 3)
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries.length()") { value(2) }
                jsonPath("$.entries[1].displayName") { value("Bob") }
                jsonPath("$.entries[1].pintCount") { value(0) }
                jsonPath("$.entries[1].rank") { value(2) }
            }
        }

        it("dense-ranks ties: two tied at 1, next is rank 2") {
            val alice = seedUser("lb_alice_03", "Alice")
            val bob = seedUser("lb_bob_03", "Bob")
            val carol = seedUser("lb_carol_03", "Carol")
            val group = seedGroup(alice, "LBAAAA03")
            addMember(bob, group)
            addMember(carol, group)
            seedPints(alice, group, 5)
            seedPints(bob, group, 5)
            seedPints(carol, group, 2)
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].rank") { value(1) }
                jsonPath("$.entries[0].isCrown") { value(true) }
                jsonPath("$.entries[1].rank") { value(1) }
                jsonPath("$.entries[1].isCrown") { value(true) }
                // Dense ranking: after two tied at 1, the next distinct count is rank 2.
                jsonPath("$.entries[2].displayName") { value("Carol") }
                jsonPath("$.entries[2].rank") { value(2) }
                jsonPath("$.entries[2].isCrown") { value(false) }
            }
        }

        it("three-way tie all share rank 1") {
            val alice = seedUser("lb_alice_04", "Alice")
            val bob = seedUser("lb_bob_04", "Bob")
            val carol = seedUser("lb_carol_04", "Carol")
            val group = seedGroup(alice, "LBAAAA04")
            addMember(bob, group)
            addMember(carol, group)
            seedPints(alice, group, 3)
            seedPints(bob, group, 3)
            seedPints(carol, group, 3)
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].rank") { value(1) }
                jsonPath("$.entries[1].rank") { value(1) }
                jsonPath("$.entries[2].rank") { value(1) }
            }
        }

        it("this_week only counts pints in the current ISO week") {
            val alice = seedUser("lb_alice_05", "Alice")
            val group = seedGroup(alice, "LBAAAA05")
            seedPints(alice, group, 2, Instant.now())
            seedPints(alice, group, 4, Instant.now().minus(14, ChronoUnit.DAYS))
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=this_week") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].pintCount") { value(2) }
            }
        }

        it("this_month only counts pints in the current calendar month") {
            val alice = seedUser("lb_alice_06", "Alice")
            val group = seedGroup(alice, "LBAAAA06")
            seedPints(alice, group, 3, Instant.now())
            seedPints(alice, group, 7, Instant.now().minus(60, ChronoUnit.DAYS))
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=this_month") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].pintCount") { value(3) }
            }
        }

        it("all_time counts every pint and is the default") {
            val alice = seedUser("lb_alice_07", "Alice")
            val group = seedGroup(alice, "LBAAAA07")
            seedPints(alice, group, 1, Instant.now())
            seedPints(alice, group, 1, Instant.now().minus(400, ChronoUnit.DAYS))
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].pintCount") { value(2) }
            }
        }

        it("computes delta from the previous week's snapshot") {
            val alice = seedUser("lb_alice_08", "Alice")
            val group = seedGroup(alice, "LBAAAA08")
            seedPints(alice, group, 3, Instant.now())
            // Alice was rank 3 last week; she's rank 1 now → delta = 3 − 1 = 2.
            val lastWeek = Instant.now().minus(7, ChronoUnit.DAYS).atZone(ZoneOffset.UTC).toLocalDate()
            val key = "%04d-W%02d".format(
                lastWeek.get(IsoFields.WEEK_BASED_YEAR),
                lastWeek.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            )
            leaderboardSnapshotRepository.save(
                LeaderboardSnapshotEntity(
                    groupId = group.id!!, userId = alice.id!!,
                    periodType = "week", periodKey = key, rank = 3, pintCount = 1
                )
            )
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=this_week") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].delta") { value(2) }
            }
        }

        it("delta is null when no snapshot exists for the member") {
            val alice = seedUser("lb_alice_09", "Alice")
            val group = seedGroup(alice, "LBAAAA09")
            seedPints(alice, group, 2, Instant.now())
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=this_week") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].delta") { value(null) }
            }
        }

        it("delta is always null for all_time") {
            val alice = seedUser("lb_alice_10", "Alice")
            val group = seedGroup(alice, "LBAAA010")
            seedPints(alice, group, 2, Instant.now())
            // A stray weekly snapshot must not leak into an all_time response.
            val lastWeek = Instant.now().minus(7, ChronoUnit.DAYS).atZone(ZoneOffset.UTC).toLocalDate()
            val key = "%04d-W%02d".format(
                lastWeek.get(IsoFields.WEEK_BASED_YEAR),
                lastWeek.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            )
            leaderboardSnapshotRepository.save(
                LeaderboardSnapshotEntity(
                    groupId = group.id!!, userId = alice.id!!,
                    periodType = "week", periodKey = key, rank = 5, pintCount = 1
                )
            )
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=all_time") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].delta") { value(null) }
            }
        }

        it("lists former members separately, unranked") {
            val alice = seedUser("lb_alice_11", "Alice")
            val ghost = seedUser("lb_ghost_11", "Ghost")
            val group = seedGroup(alice, "LBAAA011")
            seedPints(alice, group, 2)
            // Ghost has pints in the group but no membership row → former member.
            seedPints(ghost, group, 9)
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                // Ghost's 9 pints must not push Alice out of rank 1.
                jsonPath("$.entries.length()") { value(1) }
                jsonPath("$.entries[0].displayName") { value("Alice") }
                jsonPath("$.entries[0].rank") { value(1) }
                jsonPath("$.formerMembers.length()") { value(1) }
                jsonPath("$.formerMembers[0].displayName") { value("Ghost") }
                jsonPath("$.formerMembers[0].pintCount") { value(9) }
            }
        }

        it("returns an empty leaderboard for a group with no members and no pints") {
            // A lone group whose only member (the creator) is present but logged nothing.
            val alice = seedUser("lb_alice_12", "Alice")
            val group = seedGroup(alice, "LBAAA012")
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries.length()") { value(1) }
                jsonPath("$.entries[0].pintCount") { value(0) }
                jsonPath("$.formerMembers.length()") { value(0) }
            }
        }

        it("returns 403 when the user is not a member of the group") {
            val owner = seedUser("lb_owner_13", "Owner")
            val group = seedGroup(owner, "LBAAA013")
            val outsider = seedUser("lb_outsider_13", "Outsider")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("rejects an unknown period with 400") {
            val alice = seedUser("lb_alice_14", "Alice")
            val group = seedGroup(alice, "LBAAA014")
            val jwt = jwtService.generateToken(alice.id!!)

            mockMvc.get("/groups/${group.id}/leaderboard?period=yesterday") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("period") }
            }
        }

        it("returns 401 without a JWT") {
            val alice = seedUser("lb_alice_15", "Alice")
            val group = seedGroup(alice, "LBAAA015")

            mockMvc.get("/groups/${group.id}/leaderboard").andExpect {
                status { isUnauthorized() }
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
