package com.pintking.api.common

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/test")
class TestController {

    @GetMapping("/unauthorized")
    fun unauthorized(): Nothing = throw UnauthorizedException()

    @GetMapping("/forbidden")
    fun forbidden(): Nothing = throw ForbiddenException()

    @GetMapping("/not-found")
    fun notFound(): Nothing = throw NotFoundException()

    @GetMapping("/conflict")
    fun conflict(): Nothing = throw ConflictException()

    @GetMapping("/validation")
    fun validation(): Nothing = throw ValidationException(
        fieldErrors = listOf(
            FieldError("name", "must not be blank"),
            FieldError("email", "must be a valid email")
        )
    )

    @GetMapping("/unprocessable")
    fun unprocessable(): Nothing = throw UnprocessableException("File too large")

    @GetMapping("/custom-not-found")
    fun customNotFound(): Nothing = throw NotFoundException("Group not found")

    @PostMapping("/bean-validation")
    fun beanValidation(@Valid @RequestBody request: TestRequest): String = "ok"

    @GetMapping("/paginated")
    fun paginated(): PageResponse<String> = PageResponse(
        data = listOf("item1", "item2"),
        page = 0,
        size = 10,
        total = 25
    )
}

data class TestRequest(
    @field:NotBlank
    val name: String
)
