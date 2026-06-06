package com.pintking.api.user

import com.pintking.api.auth.JwtService
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldStartWith
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.multipart
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException

@SpringBootTest
@AutoConfigureMockMvc
class AvatarUploadTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val jwtService: JwtService,
    private val s3Client: S3Client
) : DescribeSpec({

    beforeEach {
        userRepository.deleteAll()
    }

    fun seedUser(appleId: String): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = "Tester"))

    fun objectExists(key: String): Boolean =
        try {
            s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            true
        } catch (e: NoSuchKeyException) {
            false
        }

    describe("POST /users/me/avatar") {

        it("uploads a valid JPEG and stores the key") {
            val user = seedUser("apple_avatar_001")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "a.jpg", "image/jpeg", JPEG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.avatarUrl") { isNotEmpty() }
            }

            val stored = userRepository.findById(user.id!!).get().avatarUrl
            stored shouldStartWith "avatars/${user.id}/"
            objectExists(stored!!) shouldBe true
        }

        it("uploads a valid PNG and stores the key") {
            val user = seedUser("apple_avatar_002")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "a.png", "image/png", PNG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
            }

            userRepository.findById(user.id!!).get().avatarUrl shouldNotBe null
        }

        it("rejects a file larger than 5 MB with 422") {
            val user = seedUser("apple_avatar_003")
            val jwt = jwtService.generateToken(user.id!!)
            // Valid JPEG header followed by enough padding to exceed 5 MB.
            val big = JPEG_BYTES + ByteArray(5 * 1024 * 1024 + 1)

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "big.jpg", "image/jpeg", big))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            userRepository.findById(user.id!!).get().avatarUrl shouldBe null
        }

        it("rejects a non-image file with 422") {
            val user = seedUser("apple_avatar_004")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "notes.txt", "text/plain", "hello world".toByteArray()))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            userRepository.findById(user.id!!).get().avatarUrl shouldBe null
        }

        it("deletes the previous avatar object on re-upload") {
            val user = seedUser("apple_avatar_005")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "a.jpg", "image/jpeg", JPEG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isOk() } }
            val firstKey = userRepository.findById(user.id!!).get().avatarUrl!!

            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "b.png", "image/png", PNG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect { status { isOk() } }
            val secondKey = userRepository.findById(user.id!!).get().avatarUrl!!

            secondKey shouldNotBe firstKey
            objectExists(firstKey) shouldBe false
            objectExists(secondKey) shouldBe true
        }

        it("returns 401 without a JWT") {
            mockMvc.multipart("/users/me/avatar") {
                file(MockMultipartFile("file", "a.jpg", "image/jpeg", JPEG_BYTES))
            }.andExpect {
                status { isUnauthorized() }
            }
        }
    }
}) {
    companion object {
        private const val BUCKET = "pint-king-photos"

        // Minimal valid magic-byte prefixes; the bytes after the signature are irrelevant.
        private val JPEG_BYTES = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0x00)
        private val PNG_BYTES = byteArrayOf(
            0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00
        )

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
