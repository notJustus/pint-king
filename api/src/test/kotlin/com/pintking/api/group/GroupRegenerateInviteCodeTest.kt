package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldMatch
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName

@SpringBootTest
@AutoConfigureMockMvc
class GroupRegenerateInviteCodeTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
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

    describe("POST /groups/{id}/invite-code/regenerate") {

        it("lets an admin regenerate: a new code is stored and returned") {
            val admin = seedUser("apple_rc_admin_01")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP001")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.inviteCode") { value(org.hamcrest.Matchers.not("RCGRP001")) }
            }

            groupRepository.findById(group.id!!).get().inviteCode shouldNotBe "RCGRP001"
        }

        it("invalidates the old code: joining with it now 404s") {
            val admin = seedUser("apple_rc_admin_02")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP002")
            val joiner = seedUser("apple_rc_joiner_02")
            val adminJwt = jwtService.generateToken(admin.id!!)
            val joinerJwt = jwtService.generateToken(joiner.id!!)

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
                header("Authorization", "Bearer $adminJwt")
            }.andExpect {
                status { isOk() }
            }

            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer $joinerJwt")
                contentType = org.springframework.http.MediaType.APPLICATION_JSON
                content = """{"inviteCode":"RCGRP002"}"""
            }.andExpect {
                status { isNotFound() }
            }
        }

        it("returns a valid 8-character alphanumeric code") {
            val admin = seedUser("apple_rc_admin_03")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP003")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
            }

            groupRepository.findById(group.id!!).get().inviteCode shouldMatch Regex("[A-Za-z0-9]{8}")
        }

        it("returns 403 when a non-admin member attempts to regenerate") {
            val admin = seedUser("apple_rc_admin_04")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP004")
            val member = seedUser("apple_rc_member_04")
            addMember(member, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }

            groupRepository.findById(group.id!!).get().inviteCode shouldBe "RCGRP004"
        }

        it("returns 403 when a non-member attempts to regenerate") {
            val admin = seedUser("apple_rc_admin_05")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP005")
            val outsider = seedUser("apple_rc_outsider_05")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }

            groupRepository.findById(group.id!!).get().inviteCode shouldBe "RCGRP005"
        }

        it("returns 401 without a JWT") {
            val admin = seedUser("apple_rc_admin_06")
            val group = seedGroup(admin, name = "Crew", code = "RCGRP006")

            mockMvc.post("/groups/${group.id}/invite-code/regenerate") {
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
