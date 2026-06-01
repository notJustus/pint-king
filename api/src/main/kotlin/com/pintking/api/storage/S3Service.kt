package com.pintking.api.storage

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest
import software.amazon.awssdk.services.s3.model.GetObjectRequest
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest
import java.time.Duration
import java.util.UUID

@Service
class S3Service(
    private val s3Client: S3Client,
    private val s3Presigner: S3Presigner,
    @Value("\${app.s3.bucket}") private val bucket: String
) {

    fun uploadPhoto(userId: UUID, groupId: UUID?, fileBytes: ByteArray): String {
        val groupSegment = groupId?.toString() ?: "no-group"
        val key = "pints/$userId/$groupSegment/${UUID.randomUUID()}.jpg"
        putObject(key, fileBytes)
        return key
    }

    fun uploadAvatar(userId: UUID, fileBytes: ByteArray): String {
        val key = "avatars/$userId/${UUID.randomUUID()}.jpg"
        putObject(key, fileBytes)
        return key
    }

    fun deleteObject(key: String) {
        s3Client.deleteObject(
            DeleteObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build()
        )
    }

    fun generatePresignedUrl(key: String): String {
        val presignRequest = GetObjectPresignRequest.builder()
            .signatureDuration(Duration.ofMinutes(15))
            .getObjectRequest(
                GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build()
            )
            .build()

        return s3Presigner.presignGetObject(presignRequest).url().toString()
    }

    private fun putObject(key: String, fileBytes: ByteArray) {
        s3Client.putObject(
            PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType("image/jpeg")
                .build(),
            RequestBody.fromBytes(fileBytes)
        )
    }
}
