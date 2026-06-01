package com.pintking.api.common

/**
 * Custom exceptions mapped to HTTP status codes by GlobalExceptionHandler.
 */

class UnauthorizedException(message: String = "Unauthorized") : RuntimeException(message)

class ForbiddenException(message: String = "Forbidden") : RuntimeException(message)

class NotFoundException(message: String = "Not found") : RuntimeException(message)

class ConflictException(message: String = "Conflict") : RuntimeException(message)

class UnprocessableException(message: String = "Unprocessable entity") : RuntimeException(message)
