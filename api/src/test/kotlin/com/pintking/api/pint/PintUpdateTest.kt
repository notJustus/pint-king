package com.pintking.api.pint

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.patch
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class PintUpdateTest(
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

    fun seedPint(user: UserEntity, group: GroupEntity, note: String? = null, drinkType: String? = null): PintLogEntity =
        pintLogRepository.save(
            PintLogEntity(
                userId = user.id!!,
                groupId = group.id!!,
                photoUrl = "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg",
                note = note,
                drinkType = drinkType,
                loggedAt = Instant.now()
            )
        )

    describe("PATCH /pints/{id}") {

        it("lets the creator update the note") {
            val user = seedUser("apple_upd_001")
            val group = seedGroup(user, "UPDAAAA1")
            val pint = seedPint(user, group, note = "old")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"new note"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.note") { value("new note") }
            }

            pintLogRepository.findById(pint.id!!).get().note shouldBe "new note"
        }

        it("lets the creator update the drink type") {
            val user = seedUser("apple_upd_002")
            val group = seedGroup(user, "UPDAAAA2")
            val pint = seedPint(user, group, drinkType = "beer")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"drinkType":"stout"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.drinkType") { value("stout") }
            }

            pintLogRepository.findById(pint.id!!).get().drinkType shouldBe "stout"
        }

        it("leaves a field untouched when it is absent from the body") {
            val user = seedUser("apple_upd_003")
            val group = seedGroup(user, "UPDAAAA3")
            val pint = seedPint(user, group, note = "keep me", drinkType = "ale")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"drinkType":"cider"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.note") { value("keep me") }
                jsonPath("$.drinkType") { value("cider") }
            }
        }

        it("clears the note when an empty string is sent") {
            val user = seedUser("apple_upd_004")
            val group = seedGroup(user, "UPDAAAA4")
            val pint = seedPint(user, group, note = "old")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"   "}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.note") { doesNotExist() }
            }

            pintLogRepository.findById(pint.id!!).get().note.shouldBeNull()
        }

        it("returns 403 when a non-creator tries to update") {
            val creator = seedUser("apple_upd_005a")
            val group = seedGroup(creator, "UPDAAAA5")
            val pint = seedPint(creator, group, note = "mine")
            val other = seedUser("apple_upd_005b")
            groupMemberRepository.save(
                GroupMemberEntity(userId = other.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
            )
            val jwt = jwtService.generateToken(other.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"hijack"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }

            pintLogRepository.findById(pint.id!!).get().note shouldBe "mine"
        }

        it("returns 400 for a note longer than 280 characters") {
            val user = seedUser("apple_upd_006")
            val group = seedGroup(user, "UPDAAAA6")
            val pint = seedPint(user, group, note = "old")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"${"x".repeat(281)}"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("note") }
            }

            pintLogRepository.findById(pint.id!!).get().note shouldBe "old"
        }

        it("returns 400 for an invalid drink type") {
            val user = seedUser("apple_upd_007")
            val group = seedGroup(user, "UPDAAAA7")
            val pint = seedPint(user, group, drinkType = "beer")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"drinkType":"whisky"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("drinkType") }
            }

            pintLogRepository.findById(pint.id!!).get().drinkType shouldBe "beer"
        }

        it("returns 404 when the pint does not exist") {
            val user = seedUser("apple_upd_008")
            seedGroup(user, "UPDAAAA8")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/pints/${UUID.randomUUID()}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"ghost"}"""
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNotFound() }
            }
        }

        it("returns 401 without a JWT") {
            val user = seedUser("apple_upd_009")
            val group = seedGroup(user, "UPDAAAA9")
            val pint = seedPint(user, group)

            mockMvc.patch("/pints/${pint.id}") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"note":"x"}"""
            }.andExpect {
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
