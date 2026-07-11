package com.pintking.api.common

class UnauthorizedException(message: String = "Unauthorized") : RuntimeException(message)

class ForbiddenException(message: String = "Forbidden") : RuntimeException(message)

/**
 * A 400 whose payload is a single human-readable message (no field-level errors).
 * Use for a bad *request state* — e.g. "promote another admin before leaving" —
 * as opposed to [ValidationException], which reports malformed input fields.
 */
class BadRequestException(message: String = "Bad request") : RuntimeException(message)

class NotFoundException(message: String = "Not found") : RuntimeException(message)

class ConflictException(message: String = "Conflict") : RuntimeException(message)

class ValidationException(
    val fieldErrors: List<FieldError>
) : RuntimeException("Validation failed")

class UnprocessableException(message: String = "Unprocessable entity") : RuntimeException(message)
