package com.pintking.api.user

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.patch
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        // Clear active-group references first: users.active_group_id → groups
        // and groups.created_by → users form a cycle, so groups can't be
        // deleted while any user still points at one.
        val users = userRepository.findAll().onEach { it.activeGroupId = null }
        userRepository.saveAll(users)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(createdBy: UUID, name: String = "The Pub", code: String = "ABCD1234"): GroupEntity =
        groupRepository.save(GroupEntity(name = name, inviteCode = code, createdBy = createdBy))

    fun joinGroup(userId: UUID, groupId: UUID) {
        groupMemberRepository.save(
            GroupMemberEntity(userId = userId, groupId = groupId, role = GroupMemberEntity.ROLE_MEMBER)
        )
    }

    describe("GET /users/me") {

        it("returns the authenticated user's profile") {
            val user = seedUser("apple_me_001", displayName = "Justus")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.id") { value(user.id.toString()) }
                jsonPath("$.displayName") { value("Justus") }
                jsonPath("$.avatarUrl") { value(null) }
                jsonPath("$.activeGroupId") { value(null) }
            }
        }

        it("returns 401 without a JWT") {
            mockMvc.get("/users/me").andExpect {
                status { isUnauthorized() }
            }
        }
    }

    describe("PATCH /users/me") {

        it("updates the display name") {
            val user = seedUser("apple_me_002", displayName = "Old Name")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/users/me") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"displayName": "New Name"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.displayName") { value("New Name") }
            }

            userRepository.findById(user.id!!).get().displayName shouldBe "New Name"
        }

        it("rejects an empty display name with 400") {
            val user = seedUser("apple_me_003")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/users/me") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"displayName": "   "}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("displayName") }
            }
        }

        it("rejects a display name longer than 30 characters with 400") {
            val user = seedUser("apple_me_004")
            val jwt = jwtService.generateToken(user.id!!)
            val tooLong = "x".repeat(31)

            mockMvc.patch("/users/me") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"displayName": "$tooLong"}"""
            }.andExpect {
                status { isBadRequest() }
            }
        }

        it("sets the active group when the user is a member") {
            val user = seedUser("apple_me_005")
            val group = seedGroup(createdBy = user.id!!)
            joinGroup(user.id!!, group.id!!)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/users/me") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"activeGroupId": "${group.id}"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.activeGroupId") { value(group.id.toString()) }
            }

            userRepository.findById(user.id!!).get().activeGroupId shouldBe group.id
        }

        it("rejects an active group the user is not a member of with 400") {
            val user = seedUser("apple_me_006")
            val otherUser = seedUser("apple_me_007")
            val group = seedGroup(createdBy = otherUser.id!!)
            // user is NOT a member of group
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/users/me") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"activeGroupId": "${group.id}"}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("activeGroupId") }
            }

            userRepository.findById(user.id!!).get().activeGroupId shouldBe null
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
