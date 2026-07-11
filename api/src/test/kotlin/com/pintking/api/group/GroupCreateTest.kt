package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.booleans.shouldBeTrue
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldMatch
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class GroupCreateTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        // users.active_group_id → groups and groups.created_by → users form a
        // cycle, so break the active-group references before deleting groups.
        val users = userRepository.findAll().onEach { it.activeGroupId = null }
        userRepository.saveAll(users)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    describe("POST /groups") {

        it("creates a group, makes the creator an admin, and returns an invite code") {
            val user = seedUser("apple_grp_001")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Work Crew"}"""
            }.andExpect {
                status { isCreated() }
                jsonPath("$.name") { value("Work Crew") }
                jsonPath("$.role") { value("admin") }
                jsonPath("$.memberCount") { value(1) }
                jsonPath("$.inviteCode") { isString() }
            }

            val groups = groupRepository.findByCreatedBy(user.id!!)
            groups shouldHaveSize 1
            val membership = groupMemberRepository.findByUserIdAndGroupId(user.id!!, groups[0].id!!)
            (membership?.role == GroupMemberEntity.ROLE_ADMIN).shouldBeTrue()
        }

        it("trims the name before storing it") {
            val user = seedUser("apple_grp_002")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "  Uni Lads  "}"""
            }.andExpect {
                status { isCreated() }
                jsonPath("$.name") { value("Uni Lads") }
            }
        }

        it("rejects an empty name with 400") {
            val user = seedUser("apple_grp_003")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "   "}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("name") }
            }
        }

        it("rejects a name longer than 50 characters with 400") {
            val user = seedUser("apple_grp_004")
            val jwt = jwtService.generateToken(user.id!!)
            val tooLong = "x".repeat(51)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "$tooLong"}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("name") }
            }
        }

        it("accepts the 99th group but rejects the 100th with 422") {
            val user = seedUser("apple_grp_005")
            val jwt = jwtService.generateToken(user.id!!)

            // Seed 98 groups created by the user, directly in the DB.
            repeat(98) { i ->
                groupRepository.save(
                    GroupEntity(name = "Group $i", inviteCode = "SEED%04d".format(i), createdBy = user.id!!)
                )
            }

            // 99th via the API → succeeds.
            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Ninety-Ninth"}"""
            }.andExpect {
                status { isCreated() }
            }

            // 100th → rejected.
            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "One Hundredth"}"""
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            groupRepository.findByCreatedBy(user.id!!) shouldHaveSize 99
        }

        it("generates an 8-character alphanumeric invite code") {
            val user = seedUser("apple_grp_006")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Code Test"}"""
            }.andExpect {
                status { isCreated() }
                jsonPath("$.inviteCode") { value(org.hamcrest.Matchers.matchesPattern("[A-Za-z0-9]{8}")) }
            }

            val code = groupRepository.findByCreatedBy(user.id!!)[0].inviteCode
            code shouldMatch Regex("[A-Za-z0-9]{8}")
        }

        it("auto-sets the created group as active when the user has none") {
            val user = seedUser("apple_grp_007")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "First Group"}"""
            }.andExpect {
                status { isCreated() }
            }

            val group = groupRepository.findByCreatedBy(user.id!!)[0]
            userRepository.findById(user.id!!).get().activeGroupId shouldBe group.id
        }

        it("leaves the active group unchanged when the user already has one") {
            val user = seedUser("apple_grp_008")
            val existing = groupRepository.save(
                GroupEntity(name = "Existing", inviteCode = "EXIST001", createdBy = user.id!!)
            )
            user.activeGroupId = existing.id
            userRepository.save(user)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Second Group"}"""
            }.andExpect {
                status { isCreated() }
            }

            userRepository.findById(user.id!!).get().activeGroupId shouldBe existing.id
        }

        it("returns 401 without a JWT") {
            mockMvc.post("/groups") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "No Auth"}"""
            }.andExpect {
                status { isUnauthorized() }
            }
        }
    }
}) {
    companion object {
        private val postgres = PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.4").asCompatibleSubstituteFor("postgres")
        ).apply { start() }

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }
}
