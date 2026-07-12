package com.pintking.api.e2e

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.pintking.api.auth.RefreshTokenRepository
import com.pintking.api.auth.TestAppleTokens
import com.pintking.api.auth.TestAuthConfig
import com.pintking.api.common.Periods
import com.pintking.api.group.GroupBlockRepository
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.leaderboard.LeaderboardSnapshotJob
import com.pintking.api.leaderboard.LeaderboardSnapshotRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserRepository
import io.kotest.assertions.nondeterministic.eventually
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.booleans.shouldBeFalse
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.multipart
import org.springframework.test.web.servlet.post
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.HeadObjectRequest
import software.amazon.awssdk.services.s3.model.NoSuchKeyException
import java.net.URI
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.time.temporal.IsoFields
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

/**
 * End-to-end journeys driven entirely through the HTTP API. Unlike the per-endpoint
 * tests (which seed state directly through repositories), each spec here signs in for a
 * real JWT and threads the real tokens / IDs it gets back from one call into the next —
 * exercising that the endpoints compose the way an iOS client would drive them. The DB
 * and S3 are only inspected to confirm the side-effects the API promised actually landed.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestAuthConfig::class)
class EndToEndTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val groupBlockRepository: GroupBlockRepository,
    private val pintLogRepository: PintLogRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val leaderboardSnapshotRepository: LeaderboardSnapshotRepository,
    private val leaderboardSnapshotJob: LeaderboardSnapshotJob,
    private val s3Client: S3Client
) : DescribeSpec({

    val mapper = jacksonObjectMapper()

    beforeEach {
        leaderboardSnapshotRepository.deleteAll()
        pintLogRepository.deleteAll()
        refreshTokenRepository.deleteAll()
        // active_group_id ↔ created_by is a cycle; break the user side before groups go.
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupBlockRepository.deleteAll()
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    // ---- HTTP-driving helpers: each returns the parsed response body ----

    // A signed-in identity: the bearer token, its paired refresh token, and the user's id
    // (looked up by Apple subject — the only piece the API doesn't hand back directly).
    data class Session(val jwt: String, val refreshToken: String, val userId: UUID)

    fun signIn(appleId: String): Session {
        val token = TestAppleTokens.createValidToken(appleId)
        val result = mockMvc.post("/auth/apple") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"identityToken": "$token"}"""
        }.andExpect { status { isOk() } }.andReturn()

        val body = mapper.readTree(result.response.contentAsString)
        val userId = userRepository.findByAppleId(appleId)!!.id!!
        return Session(body.get("jwt").asText(), body.get("refreshToken").asText(), userId)
    }

    fun createGroup(jwt: String, name: String): JsonNode {
        val result = mockMvc.post("/groups") {
            header("Authorization", "Bearer $jwt")
            contentType = MediaType.APPLICATION_JSON
            content = """{"name": "$name"}"""
        }.andExpect { status { isCreated() } }.andReturn()
        return mapper.readTree(result.response.contentAsString)
    }

    // Logs a pint via multipart, returning the created-pint body (which carries a
    // pre-signed photoUrl). Only the provided optional fields are attached.
    fun logPint(
        jwt: String,
        note: String? = null,
        drinkType: String? = null,
        latitude: Double? = null,
        longitude: Double? = null
    ): JsonNode {
        val result = mockMvc.multipart("/pints") {
            file(MockMultipartFile("photo", "p.jpg", "image/jpeg", JPEG_BYTES))
            note?.let { param("note", it) }
            drinkType?.let { param("drinkType", it) }
            latitude?.let { param("latitude", it.toString()) }
            longitude?.let { param("longitude", it.toString()) }
            header("Authorization", "Bearer $jwt")
        }.andExpect { status { isCreated() } }.andReturn()
        return mapper.readTree(result.response.contentAsString)
    }

    fun objectExists(key: String): Boolean =
        try {
            s3Client.headObject(HeadObjectRequest.builder().bucket(BUCKET).key(key).build())
            true
        } catch (e: NoSuchKeyException) {
            false
        }

    // Fetches a pre-signed S3 URL over plain HTTP the way a client would, returning
    // (status code, body bytes).
    fun httpGet(url: String): Pair<Int, ByteArray> {
        val conn = URI(url).toURL().openConnection() as java.net.HttpURLConnection
        conn.requestMethod = "GET"
        return try {
            val code = conn.responseCode
            val bytes = if (code in 200..299) conn.inputStream.readBytes() else ByteArray(0)
            code to bytes
        } finally {
            conn.disconnect()
        }
    }

    describe("Auth journey: sign in → refresh → reuse detection → logout") {

        it("issues a JWT, rotates the refresh token, then wipes tokens on reuse and on logout") {
            val session = signIn("e2e_auth_001")

            // Refresh once: the old token rotates into a fresh pair.
            val refreshed = mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "${session.refreshToken}"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.jwt") { isNotEmpty() }
                jsonPath("$.refreshToken") { isNotEmpty() }
            }.andReturn()
            val rotated = mapper.readTree(refreshed.response.contentAsString).get("refreshToken").asText()

            // Reusing the now-spent original token trips reuse detection: 401 + all tokens gone.
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "${session.refreshToken}"}"""
            }.andExpect { status { isUnauthorized() } }
            refreshTokenRepository.findByUserId(session.userId) shouldBe emptyList()

            // And because the family was wiped, even the rotated token no longer works.
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "$rotated"}"""
            }.andExpect { status { isUnauthorized() } }

            // A fresh sign-in followed by logout invalidates that session's refresh token too.
            val second = signIn("e2e_auth_001")
            mockMvc.post("/auth/logout") {
                header("Authorization", "Bearer ${second.jwt}")
            }.andExpect { status { isNoContent() } }
            mockMvc.post("/auth/refresh") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"refreshToken": "${second.refreshToken}"}"""
            }.andExpect { status { isUnauthorized() } }
        }
    }

    describe("Pint lifecycle: create → S3 + DB exist → pre-signed URL works → delete") {

        it("uploads a photo, serves it via a working pre-signed URL, then cleans up on delete") {
            val session = signIn("e2e_pint_001")
            createGroup(session.jwt, "The Snug")

            val pint = logPint(session.jwt, note = "First of the night", drinkType = "stout")
            val pintId = pint.get("id").asText()

            // DB row exists and points at an object that really is in the bucket.
            val stored = pintLogRepository.findByUserId(session.userId).single()
            objectExists(stored.photoUrl) shouldBe true

            // The response's pre-signed URL is directly fetchable and returns the uploaded bytes.
            val (code, bytes) = httpGet(pint.get("photoUrl").asText())
            code shouldBe 200
            bytes.toList() shouldContainExactly JPEG_BYTES.toList()

            // Delete removes the DB row synchronously and dispatches async S3 cleanup.
            mockMvc.delete("/pints/$pintId") {
                header("Authorization", "Bearer ${session.jwt}")
            }.andExpect { status { isNoContent() } }

            pintLogRepository.findById(UUID.fromString(pintId)).isPresent shouldBe false
            eventually(10.seconds) {
                objectExists(stored.photoUrl).shouldBeFalse()
            }
        }
    }

    describe("Account deletion: full cascade with ownership hand-off and S3 cleanup") {

        it("removes the user and their pints, promotes the remaining member, and cleans up photos") {
            val admin = signIn("e2e_acct_admin")
            val group = createGroup(admin.jwt, "Doomed Crew")
            val inviteCode = group.get("inviteCode").asText()
            val groupId = UUID.fromString(group.get("id").asText())

            val member = signIn("e2e_acct_member")
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${member.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect { status { isOk() } }

            // Admin logs two pints (two S3 photos), then deletes their account.
            val photoKeys = listOf(
                logPint(admin.jwt, note = "one").let { pintLogRepository.findById(UUID.fromString(it.get("id").asText())).get().photoUrl },
                logPint(admin.jwt, note = "two").let { pintLogRepository.findById(UUID.fromString(it.get("id").asText())).get().photoUrl }
            )
            photoKeys.forEach { objectExists(it) shouldBe true }

            mockMvc.delete("/users/me") {
                header("Authorization", "Bearer ${admin.jwt}")
            }.andExpect { status { isNoContent() } }

            // User and their pints are gone; the group survives with the member promoted to admin.
            userRepository.findById(admin.userId).isPresent shouldBe false
            pintLogRepository.findByUserId(admin.userId) shouldBe emptyList()
            groupRepository.findById(groupId).isPresent shouldBe true
            groupRepository.findById(groupId).get().createdBy shouldBe member.userId
            groupMemberRepository.findByUserIdAndGroupId(member.userId, groupId)!!.role shouldBe "admin"

            // The deleted user's photos are cleaned from S3 asynchronously.
            eventually(10.seconds) {
                photoKeys.forEach { objectExists(it).shouldBeFalse() }
            }
        }
    }

    describe("Leaderboard: rank via API, snapshot the completed week, verify delta") {

        it("ranks members from logged pints and computes a delta against the snapshot") {
            val alice = signIn("e2e_lb_alice")
            val group = createGroup(alice.jwt, "Ranked Crew")
            val groupId = UUID.fromString(group.get("id").asText())
            val inviteCode = group.get("inviteCode").asText()

            val bob = signIn("e2e_lb_bob")
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${bob.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect { status { isOk() } }

            // Seed the *completed* week directly (HTTP can't backdate loggedAt): Bob led, Alice trailed.
            val lastWeek = Periods.completedWeek().from.plus(1, ChronoUnit.DAYS)
            repeat(1) { pintLogRepository.save(PintLogEntity(userId = alice.userId, groupId = groupId, photoUrl = "pints/${alice.userId}/${UUID.randomUUID()}.jpg", loggedAt = lastWeek)) }
            repeat(4) { pintLogRepository.save(PintLogEntity(userId = bob.userId, groupId = groupId, photoUrl = "pints/${bob.userId}/${UUID.randomUUID()}.jpg", loggedAt = lastWeek)) }

            leaderboardSnapshotJob.snapshotWeekly()

            val expectedKey = Periods.completedWeek().from.atZone(ZoneOffset.UTC).toLocalDate().let {
                "%04d-W%02d".format(it.get(IsoFields.WEEK_BASED_YEAR), it.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR))
            }
            val snapshot = leaderboardSnapshotRepository.findAll().associate { it.userId to Pair(it.rank, it.periodKey) }
            snapshot[bob.userId] shouldBe Pair(1, expectedKey)   // Bob was rank 1 last week
            snapshot[alice.userId] shouldBe Pair(2, expectedKey)  // Alice was rank 2

            // This week Alice logs the most via the real endpoint, flipping the ranking.
            repeat(3) { logPint(alice.jwt) }
            repeat(1) { logPint(bob.jwt) }

            val result = mockMvc.get("/groups/$groupId/leaderboard?period=this_week") {
                header("Authorization", "Bearer ${alice.jwt}")
            }.andExpect {
                status { isOk() }
                jsonPath("$.entries[0].userId") { value(alice.userId.toString()) }
                jsonPath("$.entries[0].rank") { value(1) }
                jsonPath("$.entries[0].isCrown") { value(true) }
                // Alice climbed from snapshot rank 2 to rank 1 → delta = 2 − 1 = 1.
                jsonPath("$.entries[0].delta") { value(1) }
                jsonPath("$.entries[1].userId") { value(bob.userId.toString()) }
                jsonPath("$.entries[1].rank") { value(2) }
                // Bob fell from rank 1 to rank 2 → delta = 1 − 2 = −1.
                jsonPath("$.entries[1].delta") { value(-1) }
            }.andReturn()
            mapper.readTree(result.response.contentAsString).get("entries").size() shouldBe 2
        }
    }

    describe("Map: log located pints, then bounding-box query filters by geography") {

        it("returns only the pints whose location falls inside the requested box") {
            val session = signIn("e2e_map_001")
            createGroup(session.jwt, "Wanderers")

            logPint(session.jwt, latitude = 53.3498, longitude = -6.2603)   // central Dublin — inside
            logPint(session.jwt, latitude = 40.7128, longitude = -74.0060)  // New York — outside
            logPint(session.jwt)                                            // no location — excluded

            val activeGroupId = userRepository.findById(session.userId).get().activeGroupId
            val box = "sw_lat=53.30&sw_lng=-6.30&ne_lat=53.40&ne_lng=-6.20"

            mockMvc.get("/pints/map?group_id=$activeGroupId&$box") {
                header("Authorization", "Bearer ${session.jwt}")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].latitude") { value(53.3498) }
                jsonPath("$[0].longitude") { value(-6.2603) }
                jsonPath("$[0].isFormerMember") { value(false) }
            }
        }
    }

    describe("Group join: all four outcomes over the real endpoint") {

        it("returns 200 success, 404 unknown code, 409 already-member, and 403 when blocked") {
            val admin = signIn("e2e_join_admin")
            val group = createGroup(admin.jwt, "Gatekept")
            val groupId = UUID.fromString(group.get("id").asText())
            val inviteCode = group.get("inviteCode").asText()

            // 404 — no group has this code.
            val stranger = signIn("e2e_join_stranger")
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${stranger.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "NOSUCH00"}"""
            }.andExpect { status { isNotFound() } }

            // 200 — a fresh user joins successfully.
            val member = signIn("e2e_join_member")
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${member.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.role") { value("member") }
                jsonPath("$.memberCount") { value(2) }
            }

            // 409 — the same user is already a member.
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${member.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect { status { isConflict() } }

            // 403 — the admin removes the member (creating a block), and the rejoin is refused.
            mockMvc.delete("/groups/$groupId/members/${member.userId}") {
                header("Authorization", "Bearer ${admin.jwt}")
            }.andExpect { status { isNoContent() } }
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${member.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect { status { isForbidden() } }
        }
    }

    describe("Member removal: membership deleted, block created, pints retained") {

        it("severs membership and records a block while keeping the member's pints") {
            val admin = signIn("e2e_rm_admin")
            val group = createGroup(admin.jwt, "Purge Test")
            val groupId = UUID.fromString(group.get("id").asText())
            val inviteCode = group.get("inviteCode").asText()

            val member = signIn("e2e_rm_member")
            mockMvc.post("/groups/join") {
                header("Authorization", "Bearer ${member.jwt}")
                contentType = MediaType.APPLICATION_JSON
                content = """{"inviteCode": "$inviteCode"}"""
            }.andExpect { status { isOk() } }

            val pintId = UUID.fromString(logPint(member.jwt, note = "logged before removal").get("id").asText())

            mockMvc.delete("/groups/$groupId/members/${member.userId}") {
                header("Authorization", "Bearer ${admin.jwt}")
            }.andExpect { status { isNoContent() } }

            groupMemberRepository.findByUserIdAndGroupId(member.userId, groupId) shouldBe null
            (groupBlockRepository.findByGroupIdAndUserId(groupId, member.userId) != null) shouldBe true
            pintLogRepository.findById(pintId).isPresent shouldBe true
        }
    }
}) {
    companion object {
        private const val BUCKET = "pint-king-photos"

        // Minimal valid JPEG magic bytes; the trailing byte just makes the payload non-empty.
        private val JPEG_BYTES = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0x00)

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
