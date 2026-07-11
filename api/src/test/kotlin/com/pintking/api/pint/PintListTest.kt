package com.pintking.api.pint

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
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
import java.time.temporal.ChronoUnit

@SpringBootTest
@AutoConfigureMockMvc
class PintListTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
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

    // Inserts a pint directly (no S3) so we control the logged_at timestamp.
    fun seedPint(user: UserEntity, group: GroupEntity, loggedAt: Instant, note: String? = null) {
        pintLogRepository.save(
            PintLogEntity(
                userId = user.id!!,
                groupId = group.id!!,
                photoUrl = "pints/${user.id}/${group.id}/${java.util.UUID.randomUUID()}.jpg",
                note = note,
                loggedAt = loggedAt
            )
        )
    }

    describe("GET /pints") {

        it("returns pints for the specified group, newest first, with author info") {
            val user = seedUser("apple_list_001", displayName = "Alice")
            val group = seedGroup(user, "LISTAAA1")
            val now = Instant.now()
            seedPint(user, group, now.minus(2, ChronoUnit.HOURS), note = "older")
            seedPint(user, group, now.minus(1, ChronoUnit.HOURS), note = "newer")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(2) }
                jsonPath("$.data.length()") { value(2) }
                jsonPath("$.data[0].note") { value("newer") }
                jsonPath("$.data[1].note") { value("older") }
                jsonPath("$.data[0].displayName") { value("Alice") }
                jsonPath("$.data[0].photoUrl") { isNotEmpty() }
            }
        }

        it("excludes pints from other groups") {
            val user = seedUser("apple_list_002")
            val group = seedGroup(user, "LISTAAA2")
            val otherGroup = seedGroup(user, "LISTAAA3")
            seedPint(user, group, Instant.now())
            seedPint(user, otherGroup, Instant.now())
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(1) }
            }
        }

        it("returns 403 when the user is not a member of the group") {
            val owner = seedUser("apple_list_owner_04")
            val group = seedGroup(owner, "LISTAAA4")
            val outsider = seedUser("apple_list_outsider_04")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.get("/pints?group_id=${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("paginates: page 0 and page 1 return distinct slices") {
            val user = seedUser("apple_list_005")
            val group = seedGroup(user, "LISTAAA5")
            val base = Instant.now()
            // 3 pints; page size 2 → page 0 has 2, page 1 has 1.
            repeat(3) { i -> seedPint(user, group, base.minus(i.toLong(), ChronoUnit.MINUTES), note = "n$i") }
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}&page=0&size=2") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(3) }
                jsonPath("$.page") { value(0) }
                jsonPath("$.size") { value(2) }
                jsonPath("$.data.length()") { value(2) }
                jsonPath("$.data[0].note") { value("n0") }
            }

            mockMvc.get("/pints?group_id=${group.id}&page=1&size=2") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.data.length()") { value(1) }
                jsonPath("$.data[0].note") { value("n2") }
            }
        }

        it("this_week filter excludes pints older than the current ISO week") {
            val user = seedUser("apple_list_006")
            val group = seedGroup(user, "LISTAAA6")
            seedPint(user, group, Instant.now(), note = "this week")
            seedPint(user, group, Instant.now().minus(14, ChronoUnit.DAYS), note = "two weeks ago")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}&period=this_week") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(1) }
                jsonPath("$.data[0].note") { value("this week") }
            }
        }

        it("this_month filter excludes pints older than the current calendar month") {
            val user = seedUser("apple_list_007")
            val group = seedGroup(user, "LISTAAA7")
            seedPint(user, group, Instant.now(), note = "this month")
            seedPint(user, group, Instant.now().minus(60, ChronoUnit.DAYS), note = "two months ago")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}&period=this_month") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(1) }
                jsonPath("$.data[0].note") { value("this month") }
            }
        }

        it("all_time is the default and counts every pint") {
            val user = seedUser("apple_list_008")
            val group = seedGroup(user, "LISTAAA8")
            seedPint(user, group, Instant.now())
            seedPint(user, group, Instant.now().minus(400, ChronoUnit.DAYS))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.total") { value(2) }
            }
        }

        it("rejects an unknown period with 400") {
            val user = seedUser("apple_list_009")
            val group = seedGroup(user, "LISTAAA9")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints?group_id=${group.id}&period=yesterday") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("period") }
            }
        }

        it("returns 401 without a JWT") {
            val user = seedUser("apple_list_010")
            val group = seedGroup(user, "LISTAA10")

            mockMvc.get("/pints?group_id=${group.id}").andExpect {
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
