package com.pintking.api.group

import com.pintking.api.auth.JwtService
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class GroupMemberRemovalTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val pintLogRepository: PintLogRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        // users.active_group_id → groups and groups.created_by → users form a
        // cycle, so break the active-group references before deleting groups.
        val users = userRepository.findAll().onEach { it.activeGroupId = null }
        userRepository.saveAll(users)
        pintLogRepository.deleteAll()
        groupBlockRepository.deleteAll()
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

    fun setActiveGroup(user: UserEntity, group: GroupEntity) {
        user.activeGroupId = group.id
        userRepository.save(user)
    }

    describe("DELETE /groups/{id}/members/{userId}") {

        it("lets an admin remove a member: membership deleted, block created, pints retained") {
            val admin = seedUser("apple_rm_admin_01")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP001")
            val member = seedUser("apple_rm_member_01")
            addMember(member, group)
            val pint = pintLogRepository.save(
                PintLogEntity(userId = member.id!!, groupId = group.id!!, photoUrl = "pints/keep.jpg")
            )
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/groups/${group.id}/members/${member.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            groupMemberRepository.findByUserIdAndGroupId(member.id!!, group.id!!).shouldBeNull()
            (groupBlockRepository.findByGroupIdAndUserId(group.id!!, member.id!!) != null) shouldBe true
            pintLogRepository.findById(pint.id!!).isPresent shouldBe true
        }

        it("returns 403 when a non-admin member attempts to remove someone") {
            val admin = seedUser("apple_rm_admin_02")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP002")
            val member = seedUser("apple_rm_member_02")
            val victim = seedUser("apple_rm_victim_02")
            addMember(member, group)
            addMember(victim, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.delete("/groups/${group.id}/members/${victim.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }

            (groupMemberRepository.findByUserIdAndGroupId(victim.id!!, group.id!!) != null) shouldBe true
        }

        it("returns 403 when a non-member attempts to remove someone") {
            val admin = seedUser("apple_rm_admin_03")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP003")
            val member = seedUser("apple_rm_member_03")
            addMember(member, group)
            val outsider = seedUser("apple_rm_outsider_03")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.delete("/groups/${group.id}/members/${member.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("returns 404 when the target is not a member of the group") {
            val admin = seedUser("apple_rm_admin_04")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP004")
            val stranger = seedUser("apple_rm_stranger_04")
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/groups/${group.id}/members/${stranger.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNotFound() }
            }
        }

        it("lets a non-sole-admin leave: membership deleted, no block created") {
            val admin = seedUser("apple_rm_admin_05")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP005")
            val member = seedUser("apple_rm_member_05")
            addMember(member, group)
            val jwt = jwtService.generateToken(member.id!!)

            mockMvc.delete("/groups/${group.id}/members/${member.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            groupMemberRepository.findByUserIdAndGroupId(member.id!!, group.id!!).shouldBeNull()
            groupBlockRepository.findByGroupIdAndUserId(group.id!!, member.id!!).shouldBeNull()
        }

        it("returns 400 when the sole admin tries to leave a group with other members") {
            val admin = seedUser("apple_rm_admin_06")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP006")
            val member = seedUser("apple_rm_member_06")
            addMember(member, group)
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/groups/${group.id}/members/${admin.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
            }

            (groupMemberRepository.findByUserIdAndGroupId(admin.id!!, group.id!!) != null) shouldBe true
        }

        it("deletes the group when the sole admin with no other members leaves") {
            val admin = seedUser("apple_rm_admin_07")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP007")
            setActiveGroup(admin, group)
            pintLogRepository.save(
                PintLogEntity(userId = admin.id!!, groupId = group.id!!, photoUrl = "pints/gone.jpg")
            )
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/groups/${group.id}/members/${admin.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            groupRepository.findById(group.id!!).isPresent shouldBe false
            groupMemberRepository.findByUserIdAndGroupId(admin.id!!, group.id!!).shouldBeNull()
            userRepository.findById(admin.id!!).get().activeGroupId.shouldBeNull()
        }

        it("falls back the active group to another membership when a member is removed") {
            val admin = seedUser("apple_rm_admin_08")
            val groupA = seedGroup(admin, name = "Crew A", code = "RMGRP08A")
            val groupB = seedGroup(admin, name = "Crew B", code = "RMGRP08B")
            val member = seedUser("apple_rm_member_08")
            addMember(member, groupA)
            addMember(member, groupB)
            setActiveGroup(member, groupA)
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/groups/${groupA.id}/members/${member.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isNoContent() }
            }

            userRepository.findById(member.id!!).get().activeGroupId shouldBe groupB.id
        }

        it("returns 401 without a JWT") {
            val admin = seedUser("apple_rm_admin_09")
            val group = seedGroup(admin, name = "Crew", code = "RMGRP009")
            val member = seedUser("apple_rm_member_09")
            addMember(member, group)

            mockMvc.delete("/groups/${group.id}/members/${member.id}") {
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
