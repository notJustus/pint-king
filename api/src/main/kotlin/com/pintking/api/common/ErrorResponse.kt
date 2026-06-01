package com.pintking.api.common

import java.time.Instant

data class ErrorResponse(
    val status: Int,
    val message: String,
    val timestamp: Instant = Instant.now(),
    val errors: List<FieldError>? = null
)

data class FieldError(
    val field: String,
    val message: String
)
