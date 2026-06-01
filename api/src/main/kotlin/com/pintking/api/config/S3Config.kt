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
class S3Config {

    @Value("\${app.s3.endpoint}")
    private lateinit var endpoint: String

    @Value("\${app.s3.region}")
    private lateinit var region: String

    @Bean
    fun s3Client(): S3Client {
        val builder = S3Client.builder()
            .region(Region.of(region))

        // LocalStack uses static credentials and a custom endpoint
        if (endpoint.contains("localhost") || endpoint.contains("localstack")) {
            builder
                .endpointOverride(URI.create(endpoint))
                .credentialsProvider(
                    StaticCredentialsProvider.create(
                        AwsBasicCredentials.create("test", "test")
                    )
                )
                .forcePathStyle(true)
        }

        return builder.build()
    }

    @Bean
    fun s3Presigner(): S3Presigner {
        val builder = S3Presigner.builder()
            .region(Region.of(region))

        if (endpoint.contains("localhost") || endpoint.contains("localstack")) {
            builder
                .endpointOverride(URI.create(endpoint))
                .credentialsProvider(
                    StaticCredentialsProvider.create(
                        AwsBasicCredentials.create("test", "test")
                    )
                )
        }

        return builder.build()
    }
}
