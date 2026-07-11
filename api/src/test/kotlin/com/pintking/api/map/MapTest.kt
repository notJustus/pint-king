package com.pintking.api.map

import com.pintking.api.auth.JwtService
import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import org.hamcrest.Matchers.contains
import org.locationtech.jts.geom.Coordinate
import org.locationtech.jts.geom.GeometryFactory
import org.locationtech.jts.geom.Point
import org.locationtech.jts.geom.PrecisionModel
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.time.Instant
import java.util.UUID

@SpringBootTest
@AutoConfigureMockMvc
class MapTest(
    private val mockMvc: MockMvc,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository,
    private val jwtService: JwtService
) : DescribeSpec({

    beforeEach {
        pintLogRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    // 4326 = WGS84 lon/lat, matching the pint_logs.location column's SRID.
    val geometryFactory = GeometryFactory(PrecisionModel(), 4326)

    // JTS Coordinate is (x, y) = (longitude, latitude).
    fun point(lat: Double, lng: Double): Point =
        geometryFactory.createPoint(Coordinate(lng, lat))

    fun seedUser(appleId: String, displayName: String = "Tester"): UserEntity =
        userRepository.save(UserEntity(appleId = appleId, displayName = displayName))

    fun seedGroup(creator: UserEntity, code: String): GroupEntity {
        val group = groupRepository.save(GroupEntity(name = "The Pub", inviteCode = code, createdBy = creator.id!!))
        groupMemberRepository.save(
            GroupMemberEntity(userId = creator.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
        )
        return group
    }

    fun addMember(user: UserEntity, group: GroupEntity) {
        groupMemberRepository.save(
            GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_MEMBER)
        )
    }

    fun seedPint(user: UserEntity, group: GroupEntity, location: Point?) {
        pintLogRepository.save(
            PintLogEntity(
                userId = user.id!!,
                groupId = group.id!!,
                photoUrl = "pints/${user.id}/${group.id}/${UUID.randomUUID()}.jpg",
                location = location,
                loggedAt = Instant.now()
            )
        )
    }

    // A box around central Dublin: sw (53.30, -6.30) → ne (53.40, -6.20).
    val box = "sw_lat=53.30&sw_lng=-6.30&ne_lat=53.40&ne_lng=-6.20"

    describe("GET /pints/map") {

        it("returns pints inside the bounding box and excludes those outside") {
            val user = seedUser("apple_map_001", "Alice")
            val group = seedGroup(user, "MAPAAAA1")
            seedPint(user, group, point(53.3498, -6.2603)) // inside
            seedPint(user, group, point(40.7128, -74.0060)) // New York, outside
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].latitude") { value(53.3498) }
                jsonPath("$[0].longitude") { value(-6.2603) }
                jsonPath("$[0].displayName") { value("Alice") }
                jsonPath("$[0].photoUrl") { isNotEmpty() }
                jsonPath("$[0].isFormerMember") { value(false) }
            }
        }

        it("excludes pints with no location") {
            val user = seedUser("apple_map_002")
            val group = seedGroup(user, "MAPAAAA2")
            seedPint(user, group, point(53.3498, -6.2603))
            seedPint(user, group, null)
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
            }
        }

        it("personal scope returns only the caller's pints") {
            val user = seedUser("apple_map_003", "Alice")
            val other = seedUser("apple_map_003b", "Bob")
            val group = seedGroup(user, "MAPAAAA3")
            addMember(other, group)
            seedPint(user, group, point(53.3498, -6.2603))
            seedPint(other, group, point(53.3510, -6.2610))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&scope=personal&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(1) }
                jsonPath("$[0].userId") { value(user.id.toString()) }
            }
        }

        it("group scope returns every member's pints") {
            val user = seedUser("apple_map_004", "Alice")
            val other = seedUser("apple_map_004b", "Bob")
            val group = seedGroup(user, "MAPAAAA4")
            addMember(other, group)
            seedPint(user, group, point(53.3498, -6.2603))
            seedPint(other, group, point(53.3510, -6.2610))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&scope=group&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(2) }
            }
        }

        it("flags former members' pins") {
            val user = seedUser("apple_map_005", "Alice")
            val former = seedUser("apple_map_005b", "Bob")
            val group = seedGroup(user, "MAPAAAA5")
            // Bob logged a pint then left: pint remains, membership does not.
            seedPint(former, group, point(53.3510, -6.2610))
            seedPint(user, group, point(53.3498, -6.2603))
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&scope=group&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isOk() }
                jsonPath("$.length()") { value(2) }
                // A JSONPath filter yields an array, so match the single-element result.
                jsonPath("$[?(@.userId == '${former.id}')].isFormerMember") { value(contains(true)) }
                jsonPath("$[?(@.userId == '${user.id}')].isFormerMember") { value(contains(false)) }
            }
        }

        it("returns 403 when the user is not a member of the group") {
            val owner = seedUser("apple_map_owner_06")
            val group = seedGroup(owner, "MAPAAAA6")
            val outsider = seedUser("apple_map_outsider_06")
            val jwt = jwtService.generateToken(outsider.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isForbidden() }
            }
        }

        it("rejects an unknown scope with 400") {
            val user = seedUser("apple_map_007")
            val group = seedGroup(user, "MAPAAAA7")
            val jwt = jwtService.generateToken(user.id!!)

            mockMvc.get("/pints/map?group_id=${group.id}&scope=everyone&$box") {
                header("Authorization", "Bearer $jwt")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("scope") }
            }
        }

        it("returns 401 without a JWT") {
            val user = seedUser("apple_map_008")
            val group = seedGroup(user, "MAPAAAA8")

            mockMvc.get("/pints/map?group_id=${group.id}&$box").andExpect {
                status { isUnauthorized() }
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
