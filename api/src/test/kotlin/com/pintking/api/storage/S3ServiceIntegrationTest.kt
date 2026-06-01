package com.pintking.api.storage

import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldStartWith
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.GetObjectRequest
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import java.util.UUID

@SpringBootTest
class S3ServiceIntegrationTest(
    private val s3Service: S3Service,
    private val s3Client: S3Client
) : DescribeSpec({

    describe("uploadPhoto") {
        it("uploads to the correct pints key path and returns the key") {
            val userId = UUID.randomUUID()
            val groupId = UUID.randomUUID()
            val fileBytes = "fake-jpeg-content".toByteArray()

            val key = s3Service.uploadPhoto(userId, groupId, fileBytes)

            key shouldStartWith "pints/$userId/$groupId/"
            key shouldContain ".jpg"

            val obj = s3Client.getObject(
                GetObjectRequest.builder().bucket(BUCKET).key(key).build()
            )
            obj.readAllBytes() shouldBe fileBytes
        }

        it("uploads without groupId using 'no-group' placeholder") {
            val userId = UUID.randomUUID()
            val fileBytes = "no-group-photo".toByteArray()

            val key = s3Service.uploadPhoto(userId, null, fileBytes)

            key shouldStartWith "pints/$userId/no-group/"
        }
    }

    describe("uploadAvatar") {
        it("uploads to the correct avatars key path and returns the key") {
            val userId = UUID.randomUUID()
            val fileBytes = "fake-avatar-content".toByteArray()

            val key = s3Service.uploadAvatar(userId, fileBytes)

            key shouldStartWith "avatars/$userId/"
            key shouldContain ".jpg"

            val obj = s3Client.getObject(
                GetObjectRequest.builder().bucket(BUCKET).key(key).build()
            )
            obj.readAllBytes() shouldBe fileBytes
        }
    }

    describe("deleteObject") {
        it("removes the object from S3") {
            val userId = UUID.randomUUID()
            val fileBytes = "to-be-deleted".toByteArray()
            val key = s3Service.uploadAvatar(userId, fileBytes)

            s3Service.deleteObject(key)

            var deleted = false
            try {
                s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            } catch (e: NoSuchKeyException) {
                deleted = true
            }
            deleted shouldBe true
        }
    }

    describe("generatePresignedUrl") {
        it("returns a URL that contains the bucket and key") {
            val userId = UUID.randomUUID()
            val fileBytes = "presign-test".toByteArray()
            val key = s3Service.uploadAvatar(userId, fileBytes)

            val url = s3Service.generatePresignedUrl(key)

            url shouldContain BUCKET
            url shouldContain key
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
            localstack.execInContainer(
                "awslocal", "s3", "mb", "s3://$BUCKET"
            )
        }

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
            registry.add("app.s3.endpoint") { localstack.getEndpointOverride(Service.S3).toString() }
            registry.add("app.s3.region") { localstack.region }
        }
    }
}
