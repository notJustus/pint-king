package com.pintking.api.cleanup

import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import java.util.UUID

@SpringBootTest
class OrphanCleanupJobTest(
    private val job: OrphanCleanupJob,
    private val s3Service: S3Service,
    private val s3Client: S3Client,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val pintLogRepository: PintLogRepository
) : DescribeSpec({

    fun objectExists(key: String): Boolean =
        try {
            s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            true
        } catch (e: NoSuchKeyException) {
            false
        }

    beforeEach {
        // Isolate each test: clear DB references and empty the bucket so leftover objects
        // from a previous test don't count as orphans here.
        pintLogRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
        s3Service.listAllObjects().forEach { s3Service.deleteObject(it.key) }
    }

    describe("OrphanCleanupJob") {

        it("deletes an S3 object with no DB reference") {
            val orphanKey = s3Service.uploadPhoto(UUID.randomUUID(), UUID.randomUUID(), "orphan".toByteArray())

            val deleted = job.cleanupOrphans()

            deleted shouldBe 1
            objectExists(orphanKey) shouldBe false
        }

        it("leaves an S3 object that is referenced by a pint log") {
            val user = userRepository.save(UserEntity(appleId = "cleanup_ref_01", displayName = "Ref"))
            val group = groupRepository.save(
                GroupEntity(name = "The Pub", inviteCode = "CLEANUP1", createdBy = user.id!!)
            )
            val referencedKey = s3Service.uploadPhoto(user.id!!, group.id!!, "referenced".toByteArray())
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = referencedKey)
            )

            val deleted = job.cleanupOrphans()

            deleted shouldBe 0
            objectExists(referencedKey) shouldBe true
        }

        it("leaves an S3 object referenced by a user avatar") {
            val avatarKey = s3Service.uploadAvatar(UUID.randomUUID(), "avatar".toByteArray())
            userRepository.save(
                UserEntity(appleId = "cleanup_avatar_01", displayName = "Ava", avatarUrl = avatarKey)
            )

            val deleted = job.cleanupOrphans()

            deleted shouldBe 0
            objectExists(avatarKey) shouldBe true
        }

        it("deletes every orphan while keeping referenced objects") {
            val user = userRepository.save(UserEntity(appleId = "cleanup_mix_01", displayName = "Mix"))
            val group = groupRepository.save(
                GroupEntity(name = "The Pub", inviteCode = "CLEANUP2", createdBy = user.id!!)
            )
            val keptKey = s3Service.uploadPhoto(user.id!!, group.id!!, "kept".toByteArray())
            pintLogRepository.save(
                PintLogEntity(userId = user.id!!, groupId = group.id!!, photoUrl = keptKey)
            )
            val orphan1 = s3Service.uploadPhoto(UUID.randomUUID(), UUID.randomUUID(), "o1".toByteArray())
            val orphan2 = s3Service.uploadAvatar(UUID.randomUUID(), "o2".toByteArray())

            val deleted = job.cleanupOrphans()

            deleted shouldBe 2
            objectExists(keptKey) shouldBe true
            objectExists(orphan1) shouldBe false
            objectExists(orphan2) shouldBe false
        }
    }
}) {
    companion object {
        private const val BUCKET = "pint-king-photos"

        private val postgis = DockerImageName.parse("postgis/postgis:16-3.4")
            .asCompatibleSubstituteFor("postgres")

        private val postgres = PostgreSQLContainer(postgis)
            .withDatabaseName("pintking_test")
            .withUsername("test")
            .withPassword("test")

        private val localstack = LocalStackContainer(DockerImageName.parse("localstack/localstack:3.5"))
            .withServices(Service.S3)

        init {
            postgres.start()
            localstack.start()
            localstack.execInContainer("awslocal", "s3", "mb", "s3://$BUCKET")
        }

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
            registry.add("app.s3.endpoint") { localstack.getEndpointOverride(Service.S3).toString() }
            registry.add("app.s3.region") { localstack.region }
            // Negative grace → cutoff is in the future, so freshly uploaded orphans are eligible.
            // Production keeps the default 60-minute grace to protect mid-flight uploads.
            registry.add("app.cleanup.orphan-grace-minutes") { "-60" }
        }
    }
}
