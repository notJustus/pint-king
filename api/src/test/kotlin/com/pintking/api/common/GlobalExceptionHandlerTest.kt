package com.pintking.api.common

import io.kotest.core.spec.style.DescribeSpec
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user

@WebMvcTest(controllers = [TestController::class])
@Import(GlobalExceptionHandler::class)
class GlobalExceptionHandlerTest(
    @Autowired private val mockMvc: MockMvc
) : DescribeSpec({

    describe("GlobalExceptionHandler") {

        it("maps UnauthorizedException to 401") {
            mockMvc.get("/test/unauthorized") {
                with(user("testuser"))
            }.andExpect {
                status { isUnauthorized() }
                jsonPath("$.status") { value(401) }
                jsonPath("$.message") { value("Unauthorized") }
                jsonPath("$.timestamp") { exists() }
                jsonPath("$.errors") { doesNotExist() }
            }
        }

        it("maps ForbiddenException to 403") {
            mockMvc.get("/test/forbidden") {
                with(user("testuser"))
            }.andExpect {
                status { isForbidden() }
                jsonPath("$.status") { value(403) }
                jsonPath("$.message") { value("Forbidden") }
            }
        }

        it("maps NotFoundException to 404") {
            mockMvc.get("/test/not-found") {
                with(user("testuser"))
            }.andExpect {
                status { isNotFound() }
                jsonPath("$.status") { value(404) }
                jsonPath("$.message") { value("Not found") }
            }
        }

        it("maps ConflictException to 409") {
            mockMvc.get("/test/conflict") {
                with(user("testuser"))
            }.andExpect {
                status { isConflict() }
                jsonPath("$.status") { value(409) }
                jsonPath("$.message") { value("Conflict") }
            }
        }

        it("maps ValidationException to 400 with field errors") {
            mockMvc.get("/test/validation") {
                with(user("testuser"))
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.status") { value(400) }
                jsonPath("$.message") { value("Validation failed") }
                jsonPath("$.errors[0].field") { value("name") }
                jsonPath("$.errors[0].message") { value("must not be blank") }
                jsonPath("$.errors[1].field") { value("email") }
                jsonPath("$.errors[1].message") { value("must be a valid email") }
            }
        }

        it("maps UnprocessableException to 422") {
            mockMvc.get("/test/unprocessable") {
                with(user("testuser"))
            }.andExpect {
                status { isUnprocessableEntity() }
                jsonPath("$.status") { value(422) }
                jsonPath("$.message") { value("File too large") }
            }
        }

        it("maps MethodArgumentNotValidException to 400 with field errors") {
            mockMvc.post("/test/bean-validation") {
                with(user("testuser"))
                with(csrf())
                contentType = MediaType.APPLICATION_JSON
                content = """{"name": ""}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.status") { value(400) }
                jsonPath("$.message") { value("Validation failed") }
                jsonPath("$.errors[0].field") { value("name") }
                jsonPath("$.errors[0].message") { exists() }
            }
        }

        it("maps malformed JSON to 400") {
            mockMvc.post("/test/bean-validation") {
                with(user("testuser"))
                with(csrf())
                contentType = MediaType.APPLICATION_JSON
                content = """not json at all"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.status") { value(400) }
                jsonPath("$.message") { value("Malformed request body") }
            }
        }

        it("includes custom messages in exceptions") {
            mockMvc.get("/test/custom-not-found") {
                with(user("testuser"))
            }.andExpect {
                status { isNotFound() }
                jsonPath("$.message") { value("Group not found") }
            }
        }

        it("returns paginated response envelope with correct structure") {
            mockMvc.get("/test/paginated") {
                with(user("testuser"))
            }.andExpect {
                status { isOk() }
                jsonPath("$.data[0]") { value("item1") }
                jsonPath("$.data[1]") { value("item2") }
                jsonPath("$.page") { value(0) }
                jsonPath("$.size") { value(10) }
                jsonPath("$.total") { value(25) }
            }
        }
    }
})
