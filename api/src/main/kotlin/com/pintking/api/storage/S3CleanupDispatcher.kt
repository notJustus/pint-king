package com.pintking.api.storage

import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Component

/**
 * Fire-and-forget S3 deletion, used after a DB transaction has already committed
 * (e.g. account deletion). Runs on a separate thread so the request is not blocked
 * on S3 latency. Failures are logged and left for the orphan-cleanup job to reclaim.
 */
@Component
class S3CleanupDispatcher(private val s3Service: S3Service) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Async
    fun deleteObjects(keys: Collection<String>) {
        for (key in keys) {
            try {
                s3Service.deleteObject(key)
            } catch (e: Exception) {
                // Best-effort: the orphan-cleanup job is the safety net.
                log.warn("Failed to delete S3 object '{}'; leaving for orphan cleanup", key, e)
            }
        }
    }
}
