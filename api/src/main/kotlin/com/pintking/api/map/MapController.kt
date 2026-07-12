package com.pintking.api.map

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.Instant
import java.util.UUID

@RestController
@RequestMapping("/pints")
@Tag(name = "Map", description = "Pints as map pins within a viewport bounding box.")
class MapController(
    private val mapService: MapService
) {

    @GetMapping("/map")
    @Operation(summary = "Get pints in a bounding box", description = "Returns pins for pints within the SW/NE bounding box, scoped personal or group.")
    fun getMapPints(
        @Parameter(hidden = true) @AuthenticationPrincipal userId: UUID,
        @RequestParam("group_id") groupId: UUID,
        @RequestParam(value = "scope", required = false) scope: String?,
        @RequestParam("sw_lat") swLat: Double,
        @RequestParam("sw_lng") swLng: Double,
        @RequestParam("ne_lat") neLat: Double,
        @RequestParam("ne_lng") neLng: Double
    ): ResponseEntity<List<MapPin>> =
        ResponseEntity.ok(
            mapService.getMapPints(userId, MapQuery(groupId, scope, swLat, swLng, neLat, neLng))
        )
}

data class MapQuery(
    val groupId: UUID,
    val scope: String?,
    val swLat: Double,
    val swLng: Double,
    val neLat: Double,
    val neLng: Double
)

// A single pint rendered as a map pin. `isFormerMember` greys the pin out client-side.
data class MapPin(
    val id: UUID,
    val userId: UUID,
    val displayName: String,
    val avatarUrl: String?,
    val isFormerMember: Boolean,
    val photoUrl: String,
    val note: String?,
    val drinkType: String?,
    val latitude: Double,
    val longitude: Double,
    val loggedAt: Instant
)
