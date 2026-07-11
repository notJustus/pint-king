package com.pintking.api.pint

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
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
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class PintCreateTest(
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

    // Seeds a user who is an admin of a group and has it set as their active group.
    fun seedUserWithActiveGroup(appleId: String, code: String): UserEntity {
        val user = userRepository.save(UserEntity(appleId = appleId, displayName = "Tester"))
        val group = groupRepository.save(GroupEntity(name = "The Pub", inviteCode = code, createdBy = user.id!!))
        groupMemberRepository.save(
            GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
        )
        user.activeGroupId = group.id
        return userRepository.save(user)
    }

    fun objectExists(key: String): Boolean =
        try {
            s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            true
        } catch (e: NoSuchKeyException) {
            false
        }

    describe("POST /pints") {

        it("creates a pint: S3 object exists and DB row exists") {
            val user = seedUserWithActiveGroup("apple_pint_001", "PINTAAA1")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                param("note", "Cracking pint")
                param("drinkType", "stout")
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isCreated() }
                jsonPath("$.id") { isNotEmpty() }
                jsonPath("$.groupId") { value(user.activeGroupId.toString()) }
                jsonPath("$.note") { value("Cracking pint") }
                jsonPath("$.drinkType") { value("stout") }
                jsonPath("$.photoUrl") { isNotEmpty() }
            }

            val pints = pintLogRepository.findByUserId(user.id!!)
            pints.size shouldBe 1
            pints[0].groupId shouldBe user.activeGroupId
            pints[0].photoUrl shouldStartWith "pints/${user.id}/"
            objectExists(pints[0].photoUrl) shouldBe true
        }

        it("stores the location as a PostGIS point when provided") {
            val user = seedUserWithActiveGroup("apple_pint_002", "PINTAAA2")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                param("latitude", "53.3498")
                param("longitude", "-6.2603")
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isCreated() }
                jsonPath("$.latitude") { value(53.3498) }
                jsonPath("$.longitude") { value(-6.2603) }
            }

            val pint = pintLogRepository.findByUserId(user.id!!).single()
            pint.location.shouldNotBeNull()
            pint.location!!.y shouldBe 53.3498
            pint.location!!.x shouldBe -6.2603
        }

        it("creates a pint without a location when none is provided") {
            val user = seedUserWithActiveGroup("apple_pint_003", "PINTAAA3")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.png", "image/png", PNG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isCreated() }
                jsonPath("$.latitude") { doesNotExist() }
            }

            pintLogRepository.findByUserId(user.id!!).single().location.shouldBeNull()
        }

        it("rejects a request with no photo with 422") {
            val user = seedUserWithActiveGroup("apple_pint_004", "PINTAAA4")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                param("drinkType", "beer")
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("rejects a photo larger than 10 MB with 422") {
            val user = seedUserWithActiveGroup("apple_pint_005", "PINTAAA5")
            val jwt = jwtService.generateToken(user.id!!)
            val big = JPEG_BYTES + ByteArray(10 * 1024 * 1024 + 1)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "big.jpg", "image/jpeg", big))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("rejects a non-image photo with 422") {
            val user = seedUserWithActiveGroup("apple_pint_006", "PINTAAA6")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "notes.txt", "text/plain", "hi".toByteArray()))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isUnprocessableEntity() }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("rejects an invalid drink type with 400") {
            val user = seedUserWithActiveGroup("apple_pint_007", "PINTAAA7")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                param("drinkType", "whisky")
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("drinkType") }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("rejects a note longer than 280 characters with 400") {
            val user = seedUserWithActiveGroup("apple_pint_008", "PINTAAA8")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                param("note", "x".repeat(281))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("note") }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("rejects a latitude without a longitude with 400") {
            val user = seedUserWithActiveGroup("apple_pint_009", "PINTAAA9")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                param("latitude", "53.3498")
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("location") }
            }
        }

        it("rejects logging when the user has no active group with 400") {
            val user = userRepository.save(UserEntity(appleId = "apple_pint_010", displayName = "Loner"))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
            }

            pintLogRepository.findByUserId(user.id!!).size shouldBe 0
        }

        it("returns 401 without a JWT") {
            mockMvc.multipart("/pints") {
                file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
            }.andExpect {
                status { isUnauthorized() }
            }
        }
    }
}) {
    companion object {
        private const val BUCKET = "pint-king-photos"

        // Minimal valid magic-byte prefixes; bytes after the signature are irrelevant.
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
