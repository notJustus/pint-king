package com.pintking.api.pint

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.PostMapping
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
}

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
