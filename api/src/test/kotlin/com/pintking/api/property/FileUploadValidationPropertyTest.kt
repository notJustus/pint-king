package com.pintking.api.property

import com.pintking.api.common.ImageValidation
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.byte
import io.kotest.property.arbitrary.byteArray
import io.kotest.property.arbitrary.int
import io.kotest.property.checkAll

/**
 * Feature: pint-king, Property 6: File upload validation.
 *
 * The *type* half of Property 6 — "accepted iff the content is a JPEG or PNG" — is decided
 * entirely by [ImageValidation] on the magic bytes (ADR-0037), not the client Content-Type,
 * so that is what we fuzz here. The *size* half (5 MB avatars / 10 MB pints) is a per-endpoint
 * limit checked against `bytes.size` and is boundary-tested in AvatarUploadTest / PintCreateTest;
 * we don't allocate multi-MB arrays 100× to re-prove `a > b`.
 *
 * The oracle is the specification of the signatures themselves, expressed independently of the
 * implementation: JPEG starts `FF D8 FF`; PNG is the 8-byte `89 50 4E 47 0D 0A 1A 0A`.
 */
class FileUploadValidationPropertyTest : DescribeSpec({

    val jpegMagic = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte())
    val pngMagic = byteArrayOf(
        0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    )

    // Independent oracle: does `bytes` open with the JPEG / PNG signature?
    fun startsWith(bytes: ByteArray, prefix: ByteArray): Boolean =
        bytes.size >= prefix.size && prefix.indices.all { bytes[it] == prefix[it] }

    describe("Property 6: file upload validation (type detection)") {

        it("accepts a byte array iff it opens with a real JPEG or PNG signature") {
            // Random content of random length, including too-short arrays and near-misses.
            checkAll(500, Arb.byteArray(Arb.int(0..20), Arb.byte())) { bytes ->
                val expectedJpeg = startsWith(bytes, jpegMagic)
                val expectedPng = startsWith(bytes, pngMagic)

                ImageValidation.isJpeg(bytes) shouldBe expectedJpeg
                ImageValidation.isPng(bytes) shouldBe expectedPng
                ImageValidation.isJpegOrPng(bytes) shouldBe (expectedJpeg || expectedPng)
            }
        }

        it("accepts any content prefixed with a valid signature, regardless of trailing bytes") {
            checkAll(200, Arb.byteArray(Arb.int(0..64), Arb.byte())) { tail ->
                ImageValidation.isJpegOrPng(jpegMagic + tail) shouldBe true
                ImageValidation.isJpegOrPng(pngMagic + tail) shouldBe true
            }
        }
    }
})
