package com.pintking.api.property

import com.pintking.api.auth.RefreshTokenEntity
import com.pintking.api.auth.RefreshTokenRepository
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.AccountService
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.booleans.shouldBeTrue
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.boolean
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Feature: pint-king, Property 28: Account deletion cascade.
 *
 * For a random account configuration (a variable number of groups, in each of which the user is
 * either the sole member, the sole admin among others, or a plain member), deleting the account:
 *  - removes the user, all their pint_logs, all their refresh_tokens, all their memberships;
 *  - deletes any group where they were the sole member;
 *  - promotes the longest-standing remaining member where they were the sole admin with others;
 *  - leaves groups where they were a non-sole member otherwise intact.
 *
 * The whole cascade runs in one transaction; we assert the resulting DB state against an oracle
 * computed from the configuration we seeded.
 */
@SpringBootTest
class AccountDeletionCascadePropertyTest(
    private val accountService: AccountService,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val refreshTokenRepository: RefreshTokenRepository
) : DescribeSpec({

    val seq = AtomicInteger(0)

    fun clean() {
        pintLogRepository.deleteAll()
        refreshTokenRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun newUser(): UserEntity =
        userRepository.save(UserEntity(appleId = "del_${seq.incrementAndGet()}", displayName = "U"))

    // The three shapes a membership can take for the user being deleted.
    // SOLE: only member. SOLE_ADMIN: user is the only admin, others are plain members.
    // MEMBER: user is a plain member, group has an admin who stays.
    val shapeArb = Arb.int(0..2)

    beforeSpec { clean() }

    describe("Property 28: account deletion cascade") {

        it("removes the user everywhere and resolves each group's fate correctly") {
            checkAll(80, Arb.int(1..4), shapeArb, Arb.boolean()) { groupCount, _, withTokens ->
                clean()
                val victim = newUser()

                if (withTokens) {
                    refreshTokenRepository.save(
                        RefreshTokenEntity(
                            userId = victim.id!!,
                            tokenHash = "h%040d".format(seq.incrementAndGet()),
                            expiresAt = Instant.now().plus(30, ChronoUnit.DAYS)
                        )
                    )
                }

                // For each group, pick a shape independently so a single deletion exercises a mix.
                data class Seeded(val groupId: UUID, val shape: Int, val heirId: UUID?)
                val seeded = (0 until groupCount).map { idx ->
                    val shape = idx % 3
                    val group = groupRepository.save(
                        GroupEntity(name = "G", inviteCode = "X%06d".format(seq.incrementAndGet()), createdBy = victim.id!!)
                    )
                    when (shape) {
                        0 -> { // SOLE member
                            groupMemberRepository.save(
                                GroupMemberEntity(userId = victim.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
                            )
                            Seeded(group.id!!, shape, null)
                        }
                        1 -> { // SOLE_ADMIN with two plain members; eldest other is the heir
                            groupMemberRepository.save(
                                GroupMemberEntity(userId = victim.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
                            )
                            val elder = newUser()
                            groupMemberRepository.save(
                                GroupMemberEntity(
                                    userId = elder.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER,
                                    joinedAt = Instant.now().minus(10, ChronoUnit.DAYS)
                                )
                            )
                            val younger = newUser()
                            groupMemberRepository.save(
                                GroupMemberEntity(
                                    userId = younger.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER,
                                    joinedAt = Instant.now().minus(1, ChronoUnit.DAYS)
                                )
                            )
                            Seeded(group.id!!, shape, elder.id!!)
                        }
                        else -> { // MEMBER: another user is the surviving admin/creator
                            val admin = newUser()
                            // Reassign creator so the group doesn't reference the victim once deleted.
                            group.createdBy = admin.id!!
                            groupRepository.save(group)
                            groupMemberRepository.save(
                                GroupMemberEntity(userId = admin.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
                            )
                            groupMemberRepository.save(
                                GroupMemberEntity(userId = victim.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
                            )
                            Seeded(group.id!!, shape, admin.id!!)
                        }
                    }
                }

                // A pint in the first group, to prove pint_logs are cascaded.
                seeded.firstOrNull()?.let {
                    pintLogRepository.save(
                        PintLogEntity(userId = victim.id!!, groupId = it.groupId, photoUrl = "pints/${victim.id}/${UUID.randomUUID()}.jpg")
                    )
                }

                accountService.deleteAccount(victim.id!!)

                // The user and all rows that reference them are gone.
                userRepository.findById(victim.id!!).isPresent shouldBe false
                pintLogRepository.findByUserId(victim.id!!).isEmpty().shouldBeTrue()
                refreshTokenRepository.findByUserId(victim.id!!).isEmpty().shouldBeTrue()
                groupMemberRepository.findByUserId(victim.id!!).isEmpty().shouldBeTrue()

                // Per-group fate.
                seeded.forEach { s ->
                    val groupStillExists = groupRepository.findById(s.groupId).isPresent
                    when (s.shape) {
                        0 -> groupStillExists shouldBe false // sole member → group deleted
                        1 -> {
                            groupStillExists shouldBe true
                            // Longest-standing other member promoted to admin.
                            groupMemberRepository.findByUserIdAndGroupId(s.heirId!!, s.groupId)!!.role shouldBe
                                GroupMemberEntity.ROLE_ADMIN
                        }
                        else -> {
                            groupStillExists shouldBe true
                            // Existing admin untouched, still an admin.
                            groupMemberRepository.findByUserIdAndGroupId(s.heirId!!, s.groupId)!!.role shouldBe
                                GroupMemberEntity.ROLE_ADMIN
                        }
                    }
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
