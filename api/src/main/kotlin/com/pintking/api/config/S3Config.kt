package com.pintking.api.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.presigner.S3Presigner
import java.net.URI

@Configuration
class S3Config(
    @Value("\${app.s3.endpoint}") private val endpoint: String,
    @Value("\${app.s3.region}") private val region: String,
    @Value("\${app.s3.access-key:test}") private val accessKey: String,
    @Value("\${app.s3.secret-key:test}") private val secretKey: String
) {

    private val credentials = StaticCredentialsProvider.create(
        AwsBasicCredentials.create(accessKey, secretKey)
    )

    @Bean
    fun s3Client(): S3Client =
        S3Client.builder()
            .region(Region.of(region))
            .endpointOverride(URI.create(endpoint))
            .credentialsProvider(credentials)
            .forcePathStyle(true)
            .build()

    @Bean
    fun s3Presigner(): S3Presigner =
        S3Presigner.builder()
            .region(Region.of(region))
            .endpointOverride(URI.create(endpoint))
            .credentialsProvider(credentials)
            .build()
}
