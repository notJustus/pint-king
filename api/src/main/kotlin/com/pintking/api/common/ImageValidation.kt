package com.pintking.api.common

/**
 * Validates image uploads by magic bytes rather than the client-supplied Content-Type,
 * which is trivially spoofed (see ADR-0037). Only JPEG and PNG are accepted; both the
 * avatar and pint-photo endpoints share these checks.
 */
object ImageValidation {

    fun isJpeg(bytes: ByteArray): Boolean =
        bytes.size >= 3 &&
            bytes[0] == 0xFF.toByte() &&
            bytes[1] == 0xD8.toByte() &&
            bytes[2] == 0xFF.toByte()

    fun isPng(bytes: ByteArray): Boolean =
        bytes.size >= 8 &&
            bytes[0] == 0x89.toByte() &&
            bytes[1] == 0x50.toByte() && // P
            bytes[2] == 0x4E.toByte() && // N
            bytes[3] == 0x47.toByte() && // G
            bytes[4] == 0x0D.toByte() &&
            bytes[5] == 0x0A.toByte() &&
            bytes[6] == 0x1A.toByte() &&
            bytes[7] == 0x0A.toByte()

    fun isJpegOrPng(bytes: ByteArray): Boolean = isJpeg(bytes) || isPng(bytes)
}
