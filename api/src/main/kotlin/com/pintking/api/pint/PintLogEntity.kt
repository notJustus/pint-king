package com.pintking.api.pint

import jakarta.persistence.*
import org.locationtech.jts.geom.Point
import java.time.Instant
import java.util.*

@Entity
@Table(name = "pint_logs")
class PintLogEntity(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID? = null,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @Column(name = "group_id", nullable = false)
    val groupId: UUID,

    @Column(name = "photo_url", nullable = false)
    val photoUrl: String,

    @Column(name = "note", length = 280)
    var note: String? = null,

    @Column(name = "drink_type", length = 20)
    var drinkType: String? = null,

    @Column(name = "location", columnDefinition = "geometry(Point,4326)")
    var location: Point? = null,

    @Column(name = "logged_at", nullable = false, updatable = false)
    val loggedAt: Instant = Instant.now()
)
