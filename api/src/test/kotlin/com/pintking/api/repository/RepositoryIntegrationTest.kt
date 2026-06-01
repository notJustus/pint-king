package com.pintking.api.repository

import com.pintking.api.auth.RefreshTokenEntity
import com.pintking.api.auth.RefreshTokenRepository
import com.pintking.api.group.*
import com.pintking.api.leaderboard.LeaderboardSnapshotEntity
import com.pintking.api.leaderboard.LeaderboardSnapshotRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import org.locationtech.jts.geom.Coordinate
import org.locationtech.jts.geom.GeometryFactory
import org.locationtech.jts.geom.PrecisionModel
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.time.temporal.ChronoUnit

@SpringBootTest
class RepositoryIntegrationTest(
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val pintLogRepository: PintLogRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository
) : DescribeSpec({

    val geometryFactory = GeometryFactory(PrecisionModel(), 4326)

    describe("UserEntity") {
        it("saves and retrieves a user") {
            val user = userRepository.save(
                UserEntity(appleId = "apple_save_test", displayName = "Test User")
            )

            val found = userRepository.findById(user.id!!).orElse(null)
            found.shouldNotBeNull()
            found.appleId shouldBe "apple_save_test"
            found.displayName shouldBe "Test User"
            found.avatarUrl.shouldBeNull()
            found.activeGroupId.shouldBeNull()
        }

        it("finds user by appleId") {
            userRepository.save(UserEntity(appleId = "apple_find_test", displayName = "Finder"))

            val found = userRepository.findByAppleId("apple_find_test")
            found.shouldNotBeNull()
            found.displayName shouldBe "Finder"
        }

        it("enforces unique constraint on apple_id") {
            userRepository.save(UserEntity(appleId = "apple_dup", displayName = "First"))

            shouldThrow<DataIntegrityViolationException> {
                userRepository.saveAndFlush(UserEntity(appleId = "apple_dup", displayName = "Second"))
            }
        }
    }

    describe("GroupEntity") {
        it("saves and retrieves a group") {
            val user = userRepository.save(UserEntity(appleId = "apple_grp1", displayName = "Group Creator"))
            val group = groupRepository.save(
                GroupEntity(name = "Test Group", inviteCode = "ABCD1234", createdBy = user.id!!)
            )

            val found = groupRepository.findById(group.id!!).orElse(null)
            found.shouldNotBeNull()
            found.name shouldBe "Test Group"
            found.inviteCode shouldBe "ABCD1234"
            found.createdBy shouldBe user.id
        }

        it("finds group by invite code") {
            val user = userRepository.save(UserEntity(appleId = "apple_grp2", displayName = "Creator 2"))
            groupRepository.save(GroupEntity(name = "Invite Group", inviteCode = "XYZW9876", createdBy = user.id!!))

            val found = groupRepository.findByInviteCode("XYZW9876")
            found.shouldNotBeNull()
            found.name shouldBe "Invite Group"
        }

        it("enforces unique constraint on invite_code") {
            val user = userRepository.save(UserEntity(appleId = "apple_grp3", displayName = "Creator 3"))
            groupRepository.save(GroupEntity(name = "First Group", inviteCode = "DUPL1234", createdBy = user.id!!))

            shouldThrow<DataIntegrityViolationException> {
                groupRepository.saveAndFlush(
                    GroupEntity(name = "Second Group", inviteCode = "DUPL1234", createdBy = user.id!!)
                )
            }
        }
    }

    describe("GroupMemberEntity") {
        it("saves and retrieves a group member") {
            val user = userRepository.save(UserEntity(appleId = "apple_mem1", displayName = "Member"))
            val group = groupRepository.save(
                GroupEntity(name = "Member Group", inviteCode = "MEMB1234", createdBy = user.id!!)
            )
            val member = groupMemberRepository.save(
                GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
            )

            val found = groupMemberRepository.findByUserIdAndGroupId(user.id!!, group.id!!)
            found.shouldNotBeNull()
            found.role shouldBe "admin"
            found.id shouldBe member.id
        }

        it("enforces unique constraint on (user_id, group_id)") {
            val user = userRepository.save(UserEntity(appleId = "apple_mem2", displayName = "Dup Member"))
            val group = groupRepository.save(
                GroupEntity(name = "Dup Group", inviteCode = "DUPM1234", createdBy = user.id!!)
            )
            groupMemberRepository.save(
                GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
            )

            shouldThrow<DataIntegrityViolationException> {
                groupMemberRepository.saveAndFlush(
                    GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
                )
            }
        }

        it("finds all members by group") {
            val user1 = userRepository.save(UserEntity(appleId = "apple_mem3", displayName = "Member A"))
            val user2 = userRepository.save(UserEntity(appleId = "apple_mem4", displayName = "Member B"))
            val group = groupRepository.save(
                GroupEntity(name = "Multi Group", inviteCode = "MULT1234", createdBy = user1.id!!)
            )
            groupMemberRepository.save(
                GroupMemberEntity(userId = user1.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
            )
            groupMemberRepository.save(
                GroupMemberEntity(userId = user2.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
            )

            val members = groupMemberRepository.findByGroupId(group.id!!)
            members.size shouldBe 2
        }
    }

    describe("GroupBlockEntity") {
        it("saves and retrieves a block") {
            val user = userRepository.save(UserEntity(appleId = "apple_blk1", displayName = "Blocked"))
            val creator = userRepository.save(UserEntity(appleId = "apple_blk2", displayName = "Creator"))
            val group = groupRepository.save(
                GroupEntity(name = "Block Group", inviteCode = "BLCK1234", createdBy = creator.id!!)
            )
            groupBlockRepository.save(GroupBlockEntity(groupId = group.id!!, userId = user.id!!))

            val found = groupBlockRepository.findByGroupIdAndUserId(group.id!!, user.id!!)
            found.shouldNotBeNull()
            found.userId shouldBe user.id
        }

        it("enforces unique constraint on (group_id, user_id)") {
            val user = userRepository.save(UserEntity(appleId = "apple_blk3", displayName = "Dup Block"))
            val creator = userRepository.save(UserEntity(appleId = "apple_blk4", displayName = "Creator 2"))
            val group = groupRepository.save(
                GroupEntity(name = "Dup Block Group", inviteCode = "DBLK1234", createdBy = creator.id!!)
            )
            groupBlockRepository.save(GroupBlockEntity(groupId = group.id!!, userId = user.id!!))

            shouldThrow<DataIntegrityViolationException> {
                groupBlockRepository.saveAndFlush(GroupBlockEntity(groupId = group.id!!, userId = user.id!!))
            }
        }
    }

    describe("PintLogEntity") {
        it("saves and retrieves a pint log without location") {
            val user = userRepository.save(UserEntity(appleId = "apple_pint1", displayName = "Drinker"))
            val group = groupRepository.save(
                GroupEntity(name = "Pint Group", inviteCode = "PINT1234", createdBy = user.id!!)
            )
            val pint = pintLogRepository.save(
                PintLogEntity(
                    userId = user.id!!,
                    groupId = group.id!!,
                    photoUrl = "s3://pint-king-photos/pints/photo.jpg",
                    note = "Great beer!",
                    drinkType = "beer"
                )
            )

            val found = pintLogRepository.findById(pint.id!!).orElse(null)
            found.shouldNotBeNull()
            found.photoUrl shouldBe "s3://pint-king-photos/pints/photo.jpg"
            found.note shouldBe "Great beer!"
            found.drinkType shouldBe "beer"
            found.location.shouldBeNull()
        }

        it("saves and retrieves a pint log with location") {
            val user = userRepository.save(UserEntity(appleId = "apple_pint2", displayName = "Geo Drinker"))
            val group = groupRepository.save(
                GroupEntity(name = "Geo Group", inviteCode = "GEOP1234", createdBy = user.id!!)
            )
            val point = geometryFactory.createPoint(Coordinate(-6.2603, 53.3498))
            val pint = pintLogRepository.save(
                PintLogEntity(
                    userId = user.id!!,
                    groupId = group.id!!,
                    photoUrl = "s3://pint-king-photos/pints/geo.jpg",
                    location = point
                )
            )

            val found = pintLogRepository.findById(pint.id!!).orElse(null)
            found.shouldNotBeNull()
            found.location.shouldNotBeNull()
            found.location!!.x shouldBe -6.2603
            found.location!!.y shouldBe 53.3498
        }

        it("finds pints by group ordered by logged_at desc") {
            val user = userRepository.save(UserEntity(appleId = "apple_pint3", displayName = "Multi Drinker"))
            val group = groupRepository.save(
                GroupEntity(name = "Order Group", inviteCode = "ORDR1234", createdBy = user.id!!)
            )
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = "photo1.jpg")
            )
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = "photo2.jpg")
            )

            val pints = pintLogRepository.findByGroupIdOrderByLoggedAtDesc(group.id!!)
            pints.size shouldBe 2
        }

        it("enforces FK constraint on user_id") {
            val creator = userRepository.save(UserEntity(appleId = "apple_pint_fk", displayName = "FK Creator"))
            val group = groupRepository.save(
                GroupEntity(name = "FK Group", inviteCode = "FKGR1234", createdBy = creator.id!!)
            )

            shouldThrow<DataIntegrityViolationException> {
                pintLogRepository.saveAndFlush(
                    PintLogEntity(
                        userId = java.util.UUID.randomUUID(),
                        groupId = group.id!!,
                        photoUrl = "orphan.jpg"
                    )
                )
            }
        }
    }

    describe("RefreshTokenEntity") {
        it("saves and retrieves a refresh token") {
            val user = userRepository.save(UserEntity(appleId = "apple_rt1", displayName = "Token User"))
            val token = refreshTokenRepository.save(
                RefreshTokenEntity(
                    userId = user.id!!,
                    tokenHash = "abc123def456abc123def456abc123def456abc123def456abc123def456abcd",
                    expiresAt = Instant.now().plus(30, ChronoUnit.DAYS)
                )
            )

            val found = refreshTokenRepository.findByTokenHash(token.tokenHash)
            found.shouldNotBeNull()
            found.userId shouldBe user.id
            found.used shouldBe false
        }

        it("finds tokens by user") {
            val user = userRepository.save(UserEntity(appleId = "apple_rt2", displayName = "Multi Token"))
            refreshTokenRepository.save(
                RefreshTokenEntity(
                    userId = user.id!!,
                    tokenHash = "hash_one_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    expiresAt = Instant.now().plus(30, ChronoUnit.DAYS)
                )
            )
            refreshTokenRepository.save(
                RefreshTokenEntity(
                    userId = user.id!!,
                    tokenHash = "hash_two_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    expiresAt = Instant.now().plus(30, ChronoUnit.DAYS)
                )
            )

            val tokens = refreshTokenRepository.findByUserId(user.id!!)
            tokens.size shouldBe 2
        }

        it("enforces unique constraint on token_hash") {
            val user = userRepository.save(UserEntity(appleId = "apple_rt3", displayName = "Dup Token"))
            val hash = "dup_hash_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            refreshTokenRepository.save(
                RefreshTokenEntity(userId = user.id!!, tokenHash = hash, expiresAt = Instant.now().plus(30, ChronoUnit.DAYS))
            )

            shouldThrow<DataIntegrityViolationException> {
                refreshTokenRepository.saveAndFlush(
                    RefreshTokenEntity(userId = user.id!!, tokenHash = hash, expiresAt = Instant.now().plus(30, ChronoUnit.DAYS))
                )
            }
        }
    }

    describe("LeaderboardSnapshotEntity") {
        it("saves and retrieves a snapshot") {
            val user = userRepository.save(UserEntity(appleId = "apple_lb1", displayName = "Leader"))
            val group = groupRepository.save(
                GroupEntity(name = "Leader Group", inviteCode = "LEAD1234", createdBy = user.id!!)
            )
            leaderboardSnapshotRepository.save(
                LeaderboardSnapshotEntity(
                    groupId = group.id!!,
                    userId = user.id!!,
                    periodType = "week",
                    periodKey = "2026-W22",
                    rank = 1,
                    pintCount = 5
                )
            )

            val results = leaderboardSnapshotRepository.findByGroupIdAndPeriodTypeAndPeriodKey(
                group.id!!, "week", "2026-W22"
            )
            results.size shouldBe 1
            results[0].rank shouldBe 1
            results[0].pintCount shouldBe 5
        }

        it("enforces unique constraint on (group_id, user_id, period_type, period_key)") {
            val user = userRepository.save(UserEntity(appleId = "apple_lb2", displayName = "Dup Leader"))
            val group = groupRepository.save(
                GroupEntity(name = "Dup Leader Group", inviteCode = "DLDR1234", createdBy = user.id!!)
            )
            leaderboardSnapshotRepository.save(
                LeaderboardSnapshotEntity(
                    groupId = group.id!!, userId = user.id!!,
                    periodType = "month", periodKey = "2026-05", rank = 1, pintCount = 10
                )
            )

            shouldThrow<DataIntegrityViolationException> {
                leaderboardSnapshotRepository.saveAndFlush(
                    LeaderboardSnapshotEntity(
                        groupId = group.id!!, userId = user.id!!,
                        periodType = "month", periodKey = "2026-05", rank = 2, pintCount = 8
                    )
                )
            }
        }
    }

}) {
    companion object {
        private val postgis = DockerImageName.parse("postgis/postgis:16-3.4")
            .asCompatibleSubstituteFor("postgres")

        private val postgres = PostgreSQLContainer(postgis)
            .withDatabaseName("pintking_test")
            .withUsername("test")
            .withPassword("test")

        init {
            postgres.start()
        }

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }
}
