package com.pintking.api.common

class UnauthorizedException(message: String = "Unauthorized") : RuntimeException(message)

class ForbiddenException(message: String = "Forbidden") : RuntimeException(message)

class NotFoundException(message: String = "Not found") : RuntimeException(message)

class ConflictException(message: String = "Conflict") : RuntimeException(message)

class ValidationException(
    val fieldErrors: List<FieldError>
) : RuntimeException("Validation failed")

class UnprocessableException(message: String = "Unprocessable entity") : RuntimeException(message)
