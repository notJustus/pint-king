package com.pintking.api.property

import com.pintking.api.group.GroupEntity
import com.pintking.api.group.GroupMemberEntity
import com.pintking.api.group.GroupMemberRepository
import com.pintking.api.group.GroupRepository
import com.pintking.api.map.MapQuery
import com.pintking.api.map.MapService
import com.pintking.api.pint.PintLogEntity
import com.pintking.api.pint.PintLogRepository
import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.bind
import io.kotest.property.arbitrary.double
import io.kotest.property.arbitrary.list
import io.kotest.property.checkAll
import org.locationtech.jts.geom.Coordinate
import org.locationtech.jts.geom.GeometryFactory
import org.locationtech.jts.geom.PrecisionModel
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.localstack.LocalStackContainer
import org.testcontainers.containers.localstack.LocalStackContainer.Service
import org.testcontainers.utility.DockerImageName
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

/**
 * Feature: pint-king, Property 24: Bounding-box spatial query correctness.
 *
 * For a random box and a random set of pints (some located inside, some outside, some with no
 * location at all), the PostGIS query must return exactly the located pints whose point lies within
 * the box: (a) every returned pint is inside; (b) no inside pint is missing; (c) location-less pints
 * never appear. The oracle is an independent in-JVM point-in-rectangle test.
 *
 * Points are generated strictly inside or outside the box (never on an edge) so the assertion never
 * hinges on ST_Within's boundary semantics — that edge case is out of scope for the property.
 */
@SpringBootTest
class BoundingBoxPropertyTest(
    private val mapService: MapService,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val groupMemberRepository: GroupMemberRepository,
    private val pintLogRepository: PintLogRepository
) : DescribeSpec({

    val seq = AtomicInteger(0)
    val geometryFactory = GeometryFactory(PrecisionModel(), 4326)

    fun clean() {
        pintLogRepository.deleteAll()
        userRepository.findAll().onEach { it.activeGroupId = null }.let(userRepository::saveAll)
        groupMemberRepository.deleteAll()
        groupRepository.deleteAll()
        userRepository.deleteAll()
    }

    // A well-formed box: sw strictly below/left of ne, with a margin so there is room strictly
    // inside and strictly outside within valid lon/lat ranges.
    data class Box(val swLat: Double, val swLng: Double, val neLat: Double, val neLng: Double)

    val boxArb = Arb.bind(
        Arb.double(-80.0, 0.0),   // swLat
        Arb.double(-170.0, 0.0),  // swLng
        Arb.double(1.0, 80.0),    // latSpan added to sw for ne
        Arb.double(1.0, 170.0)    // lngSpan
    ) { swLat, swLng, latSpan, lngSpan ->
        Box(swLat, swLng, swLat + latSpan, swLng + lngSpan)
    }

    beforeSpec { clean() }

    describe("Property 24: bounding-box spatial query") {

        it("returns exactly the located pints whose point lies inside the box") {
            // Each pint: a lat, a lng, and whether it should carry a location at all.
            val pintArb = Arb.bind(
                Arb.double(-89.0, 89.0),
                Arb.double(-179.0, 179.0),
                Arb.double(0.0, 1.0)
            ) { lat, lng, hasLoc -> Triple(lat, lng, hasLoc >= 0.25) }

            checkAll(120, boxArb, Arb.list(pintArb, 0..8)) { box, pintSpecs ->
                clean()
                val user = userRepository.save(UserEntity(appleId = "bb_${seq.incrementAndGet()}", displayName = "U"))
                val group = groupRepository.save(
                    GroupEntity(name = "G", inviteCode = "B%06d".format(seq.incrementAndGet()), createdBy = user.id!!)
                )
                groupMemberRepository.save(
                    GroupMemberEntity(userId = user.id!!, groupId = group.id!!, role = GroupMemberEntity.ROLE_ADMIN)
                )

                // Independent oracle: strictly inside the box (open rectangle).
                fun inside(lat: Double, lng: Double): Boolean =
                    lat > box.swLat && lat < box.neLat && lng > box.swLng && lng < box.neLng

                val expectedInsideIds = mutableSetOf<UUID>()
                pintSpecs.forEach { (lat, lng, hasLoc) ->
                    val point = if (hasLoc) geometryFactory.createPoint(Coordinate(lng, lat)) else null
                    val saved = pintLogRepository.save(
                        PintLogEntity(
                            userId = user.id!!, groupId = group.id!!,
                            photoUrl = "pints/${user.id}/${UUID.randomUUID()}.jpg",
                            location = point
                        )
                    )
                    // Nudge points off any exact edge isn't needed — the box edges come from a
                    // different arb than the points, so an exact coincidence has measure zero;
                    // but a located point counts only if strictly inside.
                    if (hasLoc && inside(lat, lng)) expectedInsideIds.add(saved.id!!)
                }

                val returned = mapService.getMapPints(
                    user.id!!,
                    MapQuery(group.id!!, "group", box.swLat, box.swLng, box.neLat, box.neLng)
                ).map { it.id }.toSet()

                returned shouldBe expectedInsideIds
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
