package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class GroupPromoteTest(
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

    describe("POST /groups/{id}/members/{userId}/promote") {

        it("lets an admin promote a member: role changes to admin") {
            val admin = seedUser("apple_pr_admin_01")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP001")
            val member = seedUser("apple_pr_member_01")
            addMember(member, group)
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/${group.id}/members/${member.id}/promote") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            groupMemberRepository.findByUserIdAndGroupId(member.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_ADMIN
        }

        it("returns 403 when a non-admin member attempts to promote someone") {
            val admin = seedUser("apple_pr_admin_02")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP002")
            val member = seedUser("apple_pr_member_02")
            val target = seedUser("apple_pr_target_02")
            addMember(member, group)
            addMember(target, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.post("/groups/${group.id}/members/${target.id}/promote") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }

            groupMemberRepository.findByUserIdAndGroupId(target.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_MEMBER
        }

        it("returns 403 when a non-member attempts to promote someone") {
            val admin = seedUser("apple_pr_admin_03")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP003")
            val member = seedUser("apple_pr_member_03")
            addMember(member, group)
            val outsider = seedUser("apple_pr_outsider_03")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.post("/groups/${group.id}/members/${member.id}/promote") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 404 when the target is not a member of the group") {
            val admin = seedUser("apple_pr_admin_04")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP004")
            val stranger = seedUser("apple_pr_stranger_04")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/${group.id}/members/${stranger.id}/promote") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNotFound() }
            }
        }

        it("is idempotent when the target is already an admin") {
            val admin = seedUser("apple_pr_admin_05")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP005")
            val coAdmin = seedUser("apple_pr_coadmin_05")
            addMember(coAdmin, group, role = GroupMemberEntity.ROLE_ADMIN)
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.post("/groups/${group.id}/members/${coAdmin.id}/promote") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            groupMemberRepository.findByUserIdAndGroupId(coAdmin.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_ADMIN
        }

        it("returns 401 without a JWT") {
            val admin = seedUser("apple_pr_admin_06")
            val group = seedGroup(admin, name = "Crew", code = "PRGRP006")
            val member = seedUser("apple_pr_member_06")
            addMember(member, group)

            mockMvc.post("/groups/${group.id}/members/${member.id}/promote") {
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
