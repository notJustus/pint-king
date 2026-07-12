package com.pintking.api.property

import com.pintking.api.common.ConflictException
import com.pintking.api.common.ForbiddenException
import com.pintking.api.common.NotFoundException
import com.pintking.api.group.CreateGroupRequest
import com.pintking.api.group.GroupBlockEntity
import com.pintking.api.group.GroupBlockRepository
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.group.GroupService
import com.pintking.api.group.JoinGroupRequest
import com.pintking.api.group.UpdateGroupRequest
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.assertions.throwables.shouldNotThrowAny
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.element
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Container-backed property tests for the group domain, covering four properties whose behaviour
 * is only meaningful against the real DB (unique constraints, membership rows, blocks):
 *
 *  - Feature: pint-king, Property 10: Invite code format invariant.
 *  - Feature: pint-king, Property 11: Group join outcome correctness.
 *  - Feature: pint-king, Property 16: Active group invariant.
 *  - Feature: pint-king, Property 26: Authorization enforcement.
 *
 * Each iteration cleans the tables first so runs are independent.
 */
@SpringBootTest
class GroupDomainPropertyTest(
    private val groupService: GroupService,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository
) : DescribeSpec({

    // A monotonically increasing suffix keeps the unique apple_id / invite_code columns distinct
    // across the hundreds of rows these properties create.
    val seq = AtomicInteger(0)

    fun clean() {
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupBlockRepository.deleteAll()
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun newUser(): UserEntity =
        userRepository.save(UserEntity(appleId = "prop_${seq.incrementAndGet()}", displayName = "U"))

    beforeSpec { clean() }

    describe("Property 10: invite code format invariant") {
        it("every created group's code is 8 alphanumeric chars and globally unique") {
            clean()
            val seen = mutableSetOf<String>()
            checkAll(150, Arb.int(1..3)) { _ ->
                val creator = newUser()
                val code = groupService.createGroup(creator.id!!, CreateGroupRequest(name = "G")).inviteCode

                code.length shouldBe 8
                code.all { it.isLetterOrDigit() && it.code < 128 } shouldBe true
                seen.contains(code) shouldBe false
                seen.add(code)
            }
        }
    }

    describe("Property 11: group join outcome correctness") {
        // The four axes: is the code known, is the joiner already a member, are they blocked?
        it("maps (code validity, membership, block) to 404 / 409 / 403 / member exactly") {
            checkAll(150, Arb.boolean(), Arb.boolean(), Arb.boolean()) { validCode, alreadyMember, blocked ->
                clean()
                val owner = newUser()
                val group = groupService.createGroup(owner.id!!, CreateGroupRequest(name = "G"))
                val joiner = newUser()

                if (alreadyMember) {
                    groupMemberRepository.save(
                        GroupMemberEntity(userId = joiner.id!!, groupId = group.id, role = GroupMemberEntity.ROLE_MEMBER)
                    )
                }
                if (blocked) {
                    groupBlockRepository.save(GroupBlockEntity(groupId = group.id, userId = joiner.id!!))
                }

                val code = if (validCode) group.inviteCode else "ZZ000000"
                val request = JoinGroupRequest(inviteCode = code)

                when {
                    // Precedence follows the service's check order: code → membership → block.
                    !validCode -> shouldThrow<NotFoundException> { groupService.joinGroup(joiner.id!!, request) }
                    alreadyMember -> shouldThrow<ConflictException> { groupService.joinGroup(joiner.id!!, request) }
                    blocked -> shouldThrow<ForbiddenException> { groupService.joinGroup(joiner.id!!, request) }
                    else -> {
                        groupService.joinGroup(joiner.id!!, request)
                        val m = groupMemberRepository.findByUserIdAndGroupId(joiner.id!!, group.id)
                        m?.role shouldBe GroupMemberEntity.ROLE_MEMBER
                    }
                }
            }
        }
    }

    describe("Property 16: active group invariant") {
        // A random walk of join/leave operations; after each step the invariant must hold:
        // active_group_id is null or references a group the user is currently a member of.
        it("active_group_id always references a current membership, or is null") {
            checkAll(60, Arb.int(3..8)) { steps ->
                clean()
                val user = newUser()
                // A pool of groups (owned by a throwaway admin) the user can join and leave.
                val owner = newUser()
                val pool = (1..3).map {
                    groupService.createGroup(owner.id!!, CreateGroupRequest(name = "G$it"))
                }

                repeat(steps) { i ->
                    val target = pool[i % pool.size]
                    val isMember = groupMemberRepository.findByUserIdAndGroupId(user.id!!, target.id) != null
                    if (isMember) {
                        // Leave (self-removal).
                        groupService.removeMember(user.id!!, target.id, user.id!!)
                    } else {
                        shouldNotThrowAny {
                            groupService.joinGroup(user.id!!, JoinGroupRequest(inviteCode = target.inviteCode))
                        }
                    }

                    // Invariant: a non-null active group must be one the user still belongs to.
                    val active = userRepository.findById(user.id!!).get().activeGroupId
                    if (active != null) {
                        (groupMemberRepository.findByUserIdAndGroupId(user.id!!, active) != null) shouldBe true
                    }
                }
            }
        }
    }

    describe("Property 26: authorization enforcement") {
        val roles = listOf(GroupMemberEntity.ROLE_ADMIN, GroupMemberEntity.ROLE_MEMBER, "none")

        it("admin-only actions require the admin role; non-members are always forbidden") {
            checkAll(120, Arb.element(roles)) { role ->
                clean()
                val owner = newUser()
                val group = groupService.createGroup(owner.id!!, CreateGroupRequest(name = "G"))
                // A second admin so the owner isn't the sole admin (keeps setup independent of role).
                val coAdmin = newUser()
                groupMemberRepository.save(
                    GroupMemberEntity(userId = coAdmin.id!!, groupId = group.id, role = GroupMemberEntity.ROLE_ADMIN)
                )

                val actor = newUser()
                if (role != "none") {
                    groupMemberRepository.save(
                        GroupMemberEntity(userId = actor.id!!, groupId = group.id, role = role)
                    )
                }

                val isAdmin = role == GroupMemberEntity.ROLE_ADMIN

                // Update group name: admin only.
                if (isAdmin) {
                    shouldNotThrowAny { groupService.updateGroup(actor.id!!, group.id, UpdateGroupRequest(name = "New")) }
                } else {
                    shouldThrow<ForbiddenException> {
                        groupService.updateGroup(actor.id!!, group.id, UpdateGroupRequest(name = "New"))
                    }
                }

                // Regenerate invite code: admin only.
                if (isAdmin) {
                    shouldNotThrowAny { groupService.regenerateInviteCode(actor.id!!, group.id) }
                } else {
                    shouldThrow<ForbiddenException> { groupService.regenerateInviteCode(actor.id!!, group.id) }
                }

                // Reading the group detail: any member, forbidden to non-members.
                if (role == "none") {
                    shouldThrow<ForbiddenException> { groupService.getGroup(actor.id!!, group.id) }
                } else {
                    shouldNotThrowAny { groupService.getGroup(actor.id!!, group.id) }
                }
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
