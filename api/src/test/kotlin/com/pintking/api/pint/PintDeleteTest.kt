package com.pintking.api.pint

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
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
class PintDeleteTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val jwtService: JwtService,
    private val s3Client: S3Client
) : DescribeSpec({

    beforeEach {
        pintLogRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(creator: UserEntity, code: String): GroupEntity {
        val group = groupRepository.save(GroupEntity(name = "The Pub", inviteCode = code, createdBy = creator.id!!))
        groupMemberRepository.save(
            GroupMemberEntity(userId = creator.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
        )
        return group
    }

    fun seedPint(user: UserEntity, group: GroupEntity, photoKey: String, loggedAt: Instant = Instant.now()): PintLogEntity =
        pintLogRepository.save(
            PintLogEntity(
                userId = user.id!!,
                groupId = group.id!!,
                photoUrl = photoKey,
                loggedAt = loggedAt
            )
        )

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

    describe("DELETE /pints/{id}") {

        it("lets the creator delete a pint within 24h and dispatches the S3 delete") {
            val user = seedUser("apple_del_p001")
            val group = seedGroup(user, "DELP0001")
            val photoKey = "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg"
            putObject(photoKey)
            val pint = seedPint(user, group, photoKey)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/pints/${pint.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            pintLogRepository.findById(pint.id!!).isPresent shouldBe false
            // Cleanup runs on a separate thread after commit — poll until it lands.
            eventually(10.seconds) {
                objectExists(photoKey).shouldBeFalse()
            }
        }

        it("returns 400 when the pint is older than 24 hours") {
            val user = seedUser("apple_del_p002")
            val group = seedGroup(user, "DELP0002")
            val photoKey = "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg"
            putObject(photoKey)
            val pint = seedPint(user, group, photoKey, loggedAt = Instant.now().minus(25, ChronoUnit.HOURS))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/pints/${pint.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isBadRequest() } }

            // Row and photo both survive a rejected delete.
            pintLogRepository.findById(pint.id!!).isPresent shouldBe true
            objectExists(photoKey) shouldBe true
        }

        it("returns 403 when a non-creator tries to delete") {
            val creator = seedUser("apple_del_p003a")
            val group = seedGroup(creator, "DELP0003")
            val photoKey = "pints/${creator.id}/${group.id}/${UUID.randomUUID()}.jpg"
            val pint = seedPint(creator, group, photoKey)
            val other = seedUser("apple_del_p003b")
            groupMemberRepository.save(
                GroupMemberEntity(userId = other.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
            )
            val jwt = jwtService.generateToken(other.id!!)

            mockMvc.delete("/pints/${pint.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isForbidden() } }

            pintLogRepository.findById(pint.id!!).isPresent shouldBe true
        }

        it("still deletes the DB row when the S3 object is already gone") {
            // The photo never existed in S3; the async cleanup swallows the failure
            // and the orphan-cleanup job is the safety net, so the row is still removed.
            val user = seedUser("apple_del_p004")
            val group = seedGroup(user, "DELP0004")
            val photoKey = "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg"
            val pint = seedPint(user, group, photoKey)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/pints/${pint.id}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNoContent() } }

            pintLogRepository.findById(pint.id!!).isPresent shouldBe false
        }

        it("returns 404 when the pint does not exist") {
            val user = seedUser("apple_del_p005")
            seedGroup(user, "DELP0005")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.delete("/pints/${UUID.randomUUID()}") {
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isNotFound() } }
        }

        it("returns 401 without a JWT") {
            val user = seedUser("apple_del_p006")
            val group = seedGroup(user, "DELP0006")
            val pint = seedPint(user, group, "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg")

            mockMvc.delete("/pints/${pint.id}").andExpect { status { isUnauthorized() } }

            pintLogRepository.findById(pint.id!!).isPresent shouldBe true
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
