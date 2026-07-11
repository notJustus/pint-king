package com.pintking.api.user

import com.pintking.api.auth.JwtService
import com.pintking.api.auth.RefreshTokenRepository
import com.pintking.api.auth.RefreshTokenService
import com.pintking.api.group.GroupBlockEntity
import com.pintking.api.group.GroupBlockRepository
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import io.kotest.assertions.nondeterministic.eventually
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.booleans.shouldBeFalse
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

@SpringBootTest
@AutoConfigureMockMvc
class AccountDeletionTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val pintLogRepository: PintLogRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val refreshTokenService: RefreshTokenService,
    private val jwtService: JwtService,
    private val s3Client: S3Client
) : DescribeSpec({

    beforeEach {
        // users.active_group_id ↔ groups.created_by is a cycle, so break the
        // user side before deleting groups.
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        pintLogRepository.deleteAll()
        refreshTokenRepository.deleteAll()
        groupBlockRepository.deleteAll()
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(createdBy: UUID, code: String): GroupEntity =
        groupRepository.save(GroupEntity(name = "The Pub", inviteCode = code, createdBy = createdBy))

    fun join(userId: UUID, groupId: UUID, role: String, joinedAt: Instant = Instant.now()) {
        groupMemberRepository.save(
            GroupMemberEntity(userId = userId, groupId = groupId, role = role, joinedAt = joinedAt)
        )
    }

    fun putObject(key: String) {
        s3Client.putObject(
            PutObjectRequest.builder().bucket(BUCKET).key(key).build(),
            RequestBody.fromBytes(byteArrayOf(1, 2, 3))
        )
    }

    fun objectExists(key: String): Boolean =
        try {
            s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            true
        } catch (e: NoSuchKeyException) {
            false
        }

    describe("DELETE /users/me") {

        it("deletes the user, their pints, and their refresh tokens") {
            val user = seedUser("apple_del_001")
            val group = seedGroup(user.id!!, "DELA0001")
            join(user.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = "pints/a.jpg")
            )
            refreshTokenService.generateRefreshToken(user.id!!)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            userRepository.findById(user.id!!).isPresent shouldBe false
            pintLogRepository.findByUserId(user.id!!) shouldBe emptyList()
            refreshTokenRepository.findByUserId(user.id!!) shouldBe emptyList()
        }

        it("promotes the longest-standing member when the sole admin deletes their account") {
            val admin = seedUser("apple_del_002")
            val group = seedGroup(admin.id!!, "DELB0001")
            val older = seedUser("apple_del_003")
            val newer = seedUser("apple_del_004")
            val base = Instant.now()
            join(admin.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN, base)
            join(older.id!!, group.id!!, GroupMemberEntity.ROLE_MEMBER, base.plus(1, ChronoUnit.HOURS))
            join(newer.id!!, group.id!!, GroupMemberEntity.ROLE_MEMBER, base.plus(2, ChronoUnit.HOURS))
            val jwt = jwtService.generateToken(admin.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            groupRepository.findById(group.id!!).isPresent shouldBe true
            groupMemberRepository.findByUserIdAndGroupId(older.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_ADMIN
            groupMemberRepository.findByUserIdAndGroupId(newer.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_MEMBER
            // Ownership handed off so the FK to the deleted user is not violated.
            groupRepository.findById(group.id!!).get().createdBy shouldBe older.id
        }

        it("deletes the group when the user is its sole member") {
            val user = seedUser("apple_del_005")
            val group = seedGroup(user.id!!, "DELC0001")
            join(user.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            groupRepository.findById(group.id!!).isPresent shouldBe false
        }

        it("leaves the group intact when another admin remains") {
            val leaving = seedUser("apple_del_006")
            val coAdmin = seedUser("apple_del_007")
            val group = seedGroup(coAdmin.id!!, "DELD0001")
            join(leaving.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)
            join(coAdmin.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)
            val jwt = jwtService.generateToken(leaving.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            groupRepository.findById(group.id!!).isPresent shouldBe true
            groupMemberRepository.findByUserIdAndGroupId(leaving.id!!, group.id!!) shouldBe null
            // Co-admin was already an admin, so no spurious promotion is needed.
            groupMemberRepository.findByUserIdAndGroupId(coAdmin.id!!, group.id!!)!!
                .role shouldBe GroupMemberEntity.ROLE_ADMIN
        }

        it("dispatches async S3 deletion of the avatar and all pint photos") {
            val user = seedUser("apple_del_008")
            val group = seedGroup(user.id!!, "DELE0001")
            join(user.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)

            val avatarKey = "avatars/${user.id}/${UUID.randomUUID()}.jpg"
            val pintKey1 = "pints/${user.id}/${UUID.randomUUID()}.jpg"
            val pintKey2 = "pints/${user.id}/${UUID.randomUUID()}.jpg"
            putObject(avatarKey)
            putObject(pintKey1)
            putObject(pintKey2)
            user.avatarUrl = avatarKey
            userRepository.save(user)
            pintLogRepository.save(PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = pintKey1))
            pintLogRepository.save(PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = pintKey2))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            // Cleanup runs on a separate thread after commit — poll until it lands.
            eventually(10.seconds) {
                objectExists(avatarKey).shouldBeFalse()
                objectExists(pintKey1).shouldBeFalse()
                objectExists(pintKey2).shouldBeFalse()
            }
        }

        it("removes the user's blocks and retains blocks about them in surviving groups") {
            // A group the leaving user does NOT belong to holds a block row for them.
            val owner = seedUser("apple_del_009")
            val leaving = seedUser("apple_del_010")
            val group = seedGroup(owner.id!!, "DELF0001")
            join(owner.id!!, group.id!!, GroupMemberEntity.ROLE_ADMIN)
            groupBlockRepository.save(GroupBlockEntity(groupId = group.id!!, userId = leaving.id!!))
            val jwt = jwtService.generateToken(leaving.id!!)

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            userRepository.findById(leaving.id!!).isPresent shouldBe false
            // The block referencing the deleted user must be gone (FK), group survives.
            groupBlockRepository.findByGroupIdAndUserId(group.id!!, leaving.id!!) shouldBe null
            groupRepository.findById(group.id!!).isPresent shouldBe true
        }

        it("returns 401 without a JWT") {
            mockMvc.delete("/users/me").andExpect { status { isUnauthorized() } }
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
