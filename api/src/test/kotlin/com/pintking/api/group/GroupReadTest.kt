package com.pintking.api.group

import com.pintking.api.auth.JwtService
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
import org.testcontainers.utility.DockerImageName

@SpringBootTest
@AutoConfigureMockMvc
class GroupReadTest(
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

    fun seedGroup(creator: UserEntity, name: String, code: String): GroupEntity {
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

    fun addMember(user: UserEntity, group: GroupEntity, role: String = GroupMemberEntity.ROLE_MEMBER) {
        groupMemberRepository.save(
            GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = role)
        )
    }

    describe("GET /groups") {

        it("returns only the groups the user is a member of") {
            val user = seedUser("apple_read_user_01")
            val mine = seedGroup(user, name = "Mine", code = "MINEGRP0")
            // A group the user does not belong to.
            val other = seedUser("apple_read_other_01")
            seedGroup(other, name = "Theirs", code = "THEIRS00")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/groups") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].id") { value(mine.id.toString()) }
                jsonPath("$[0].name") { value("Mine") }
                jsonPath("$[0].role") { value("admin") }
                jsonPath("$[0].memberCount") { value(1) }
            }
        }

        it("returns an empty list when the user belongs to no groups") {
            val user = seedUser("apple_read_user_02")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/groups") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(0) }
            }
        }

        it("returns 401 without a JWT") {
            mockMvc.get("/groups").andExpect {
                status { isUnauthorized() }
            }
        }
    }

    describe("GET /groups/{id}") {

        it("returns group details with the member list") {
            val admin = seedUser("apple_read_admin_03", displayName = "Alice")
            val group = seedGroup(admin, name = "Crew", code = "CREWGRP0")
            val member = seedUser("apple_read_member_03", displayName = "Bob")
            addMember(member, group)
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.get("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.id") { value(group.id.toString()) }
                jsonPath("$.name") { value("Crew") }
                jsonPath("$.inviteCode") { value("CREWGRP0") }
                jsonPath("$.role") { value("admin") }
                jsonPath("$.memberCount") { value(2) }
                jsonPath("$.members.length()") { value(2) }
            }
        }

        it("returns a member's own role in the detail response") {
            val admin = seedUser("apple_read_admin_04", displayName = "Alice")
            val group = seedGroup(admin, name = "Crew", code = "CREWGRP1")
            val member = seedUser("apple_read_member_04", displayName = "Bob")
            addMember(member, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.get("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.role") { value("member") }
            }
        }

        it("returns 403 when the user is not a member of the group") {
            val admin = seedUser("apple_read_admin_05")
            val group = seedGroup(admin, name = "Private", code = "PRIVATE0")
            val outsider = seedUser("apple_read_outsider_05")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.get("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 403 for a group that does not exist") {
            val user = seedUser("apple_read_user_06")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/groups/${java.util.UUID.randomUUID()}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 401 without a JWT") {
            val admin = seedUser("apple_read_admin_07")
            val group = seedGroup(admin, name = "Crew", code = "CREWGRP2")

            mockMvc.get("/groups/${group.id}").andExpect {
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
