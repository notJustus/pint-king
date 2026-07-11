package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.patch
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class GroupUpdateTest(
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

    describe("PATCH /groups/{id}") {

        it("lets an admin rename the group") {
            val admin = seedUser("apple_upd_admin_01")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP01")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "New Name"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.id") { value(group.id.toString()) }
                jsonPath("$.name") { value("New Name") }
                jsonPath("$.role") { value("admin") }
            }

            groupRepository.findById(group.id!!).get().name shouldBe "New Name"
        }

        it("trims the new name before storing it") {
            val admin = seedUser("apple_upd_admin_02")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP02")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "  Trimmed  "}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.name") { value("Trimmed") }
            }
        }

        it("rejects an empty name with 400") {
            val admin = seedUser("apple_upd_admin_03")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP03")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "   "}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("name") }
            }

            groupRepository.findById(group.id!!).get().name shouldBe "Old Name"
        }

        it("rejects a name longer than 50 characters with 400") {
            val admin = seedUser("apple_upd_admin_04")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP04")
            val jwt = jwtService.generateToken(admin.id!!)
            val tooLong = "x".repeat(51)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "$tooLong"}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("name") }
            }
        }

        it("returns 403 when a non-admin member attempts to rename") {
            val admin = seedUser("apple_upd_admin_05")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP05")
            val member = seedUser("apple_upd_member_05")
            addMember(member, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Hijacked"}"""
            }.andExpect {
                status { isForbidden() }
            }

            groupRepository.findById(group.id!!).get().name shouldBe "Old Name"
        }

        it("returns 403 when a non-member attempts to rename") {
            val admin = seedUser("apple_upd_admin_06")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP06")
            val outsider = seedUser("apple_upd_outsider_06")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.patch("/groups/${group.id}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Hijacked"}"""
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 403 for a group that does not exist") {
            val user = seedUser("apple_upd_user_07")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.patch("/groups/${UUID.randomUUID()}") {
                header("Authorization", "Bearer $jwt")
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": "Ghost"}"""
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 401 without a JWT") {
            val admin = seedUser("apple_upd_admin_08")
            val group = seedGroup(admin, name = "Old Name", code = "UPDGRP08")

            mockMvc.patch("/groups/${group.id}") {
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
