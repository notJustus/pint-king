package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

@SpringBootTest
@AutoConfigureMockMvc
class GroupJoinTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        // users.active_group_id → groups and groups.created_by → users form a
        // cycle, so break the active-group references before deleting groups.
        val users = userRepository.findAll().onEach { it.activeGroupId = null }
        userRepository.saveAll(users)
        groupBlockRepository.deleteAll()
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(creator: UserEntity, name: String = "Crew", code: String): GroupEntity {
        val group = groupRepository.save(
            GroupEntity(name = name, inviteCode = code, createdBy = creator.id!!)
        )
        groupMemberRepository.save(
            GroupMemberEntity(
                userId = creator.id!!,
                groupId = group.id!!,
                role = GroupMemberEntity.ROLE_ADMIN
            )
        )
        return group
    }

    describe("POST /groups/join") {

        it("joins a group as a member when the code is valid, user is not a member, and not blocked") {
            val admin = seedUser("apple_join_admin_01")
            val group = seedGroup(admin, code = "JOINABLE")
            val joiner = seedUser("apple_join_user_01")
            val jwt = jwtService.generateToken(joiner.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "JOINABLE"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.name") { value("Crew") }
                jsonPath("$.role") { value("member") }
                jsonPath("$.memberCount") { value(2) }
            }

            val membership = groupMemberRepository.findByUserIdAndGroupId(joiner.id!!, group.id!!)
            membership.shouldNotBeNull()
            membership.role shouldBe GroupMemberEntity.ROLE_MEMBER
        }

        it("returns 404 for an unknown invite code") {
            val user = seedUser("apple_join_user_02")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "NOSUCH00"}"""
            }.andExpect {
                status { isNotFound() }
            }
        }

        it("returns 409 when the user is already a member") {
            val admin = seedUser("apple_join_admin_03")
            seedGroup(admin, code = "ALREADY0")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "ALREADY0"}"""
            }.andExpect {
                status { isConflict() }
            }
        }

        it("returns 403 with a removal message when the user is blocked") {
            val admin = seedUser("apple_join_admin_04")
            val group = seedGroup(admin, code = "BLOCKED0")
            val blocked = seedUser("apple_join_user_04")
            groupBlockRepository.save(
                GroupBlockEntity(groupId = group.id!!, userId = blocked.id!!)
            )
            val jwt = jwtService.generateToken(blocked.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "BLOCKED0"}"""
            }.andExpect {
                status { isForbidden() }
                jsonPath("$.message") { value("You have been removed from this group") }
            }

            groupMemberRepository.findByUserIdAndGroupId(blocked.id!!, group.id!!) shouldBe null
        }

        it("auto-sets the joined group as active when the user has none") {
            val admin = seedUser("apple_join_admin_05")
            val group = seedGroup(admin, code = "AUTOACT0")
            val joiner = seedUser("apple_join_user_05")
            val jwt = jwtService.generateToken(joiner.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "AUTOACT0"}"""
            }.andExpect {
                status { isOk() }
            }

            userRepository.findById(joiner.id!!).get().activeGroupId shouldBe group.id
        }

        it("leaves the active group unchanged when the user already has one") {
            val admin = seedUser("apple_join_admin_06")
            val group = seedGroup(admin, code = "KEEPACT0")
            val joiner = seedUser("apple_join_user_06")
            val other = groupRepository.save(
                GroupEntity(name = "Other", inviteCode = "OTHER000", createdBy = joiner.id!!)
            )
            joiner.activeGroupId = other.id
            userRepository.save(joiner)
            val jwt = jwtService.generateToken(joiner.id!!)

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "KEEPACT0"}"""
            }.andExpect {
                status { isOk() }
            }

            userRepository.findById(joiner.id!!).get().activeGroupId shouldBe other.id
        }

        it("returns 401 without a JWT") {
            mockMvc.post("/groups/join") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "ANYCODE0"}"""
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
