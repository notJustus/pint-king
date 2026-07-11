package com.pintking.api.pint

import com.pintking.api.common.PageResponse
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile
import java.time.Instant
import java.util.UUID

@RestController
@RequestMapping("/pints")
class PintController(
    private val pintService: PintService
) {

    @PostMapping
    fun createPint(
        @AuthenticationPrincipal userId: UUID,
        @RequestParam(value = "photo", required = false) photo: MultipartFile?,
        @RequestParam(value = "note", required = false) note: String?,
        @RequestParam(value = "drinkType", required = false) drinkType: String?,
        @RequestParam(value = "latitude", required = false) latitude: Double?,
        @RequestParam(value = "longitude", required = false) longitude: Double?
    ): ResponseEntity<PintResponse> {
        val pint = pintService.createPint(
            userId,
            photo,
            CreatePintMetadata(note, drinkType, latitude, longitude)
        )
        return ResponseEntity.status(HttpStatus.CREATED).body(pint)
    }

    @GetMapping
    fun listPints(
        @AuthenticationPrincipal userId: UUID,
        @RequestParam("group_id") groupId: UUID,
        @RequestParam(value = "period", required = false) period: String?,
        @RequestParam(value = "page", required = false) page: Int?,
        @RequestParam(value = "size", required = false) size: Int?
    ): PageResponse<PintFeedItem> =
        pintService.listPints(userId, groupId, period, page, size)

    @PatchMapping("/{id}")
    fun updatePint(
        @AuthenticationPrincipal userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: UpdatePintRequest
    ): ResponseEntity<PintResponse> =
        ResponseEntity.ok(pintService.updatePint(userId, id, request))
}

data class UpdatePintRequest(
    val note: String? = null,
    val drinkType: String? = null
)

data class CreatePintMetadata(
    val note: String? = null,
    val drinkType: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null
)

data class PintResponse(
    val id: UUID,
    val userId: UUID,
    val groupId: UUID,
    val photoUrl: String,
    val note: String?,
    val drinkType: String?,
    val latitude: Double?,
    val longitude: Double?,
    val loggedAt: Instant
)

// A pint as it appears in a group feed: pint fields plus the author's identity.
data class PintFeedItem(
    val id: UUID,
    val userId: UUID,
    val displayName: String?,
    val avatarUrl: String?,
    val groupId: UUID,
    val photoUrl: String,
    val note: String?,
    val drinkType: String?,
    val latitude: Double?,
    val longitude: Double?,
    val loggedAt: Instant
)
