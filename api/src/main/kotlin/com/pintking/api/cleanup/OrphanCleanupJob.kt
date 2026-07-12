package com.pintking.api.cleanup

import com.pintking.api.pint.PintLogRepository
import com.pintking.api.storage.S3Service
import com.pintking.api.user.UserRepository
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Safety net for every DB ↔ S3 ordering flow (ADR-0001/0002 and account deletion): any S3 object
 * no `pint_logs.photo_url` or `users.avatar_url` still points at is orphaned and gets deleted.
 *
 * Runs daily. The correctness hinge is the [graceMinutes] window: pint creation is S3-first
 * (ADR-0001), so between the upload and the DB insert an object is *legitimately* unreferenced.
 * We only delete objects last modified before `now - grace`, so an in-flight upload is never
 * mistaken for an orphan. Deleting the DB reference before the object (deletion flows) is safe —
 * the object simply becomes eligible next run.
 */
@Component
class OrphanCleanupJob(
    private val s3Service: S3Service,
    private val pintLogRepository: PintLogRepository,
    private val userRepository: UserRepository,
    @Value("\${app.cleanup.orphan-grace-minutes:60}") private val graceMinutes: Long
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 15 3 * * *", zone = "UTC")
    fun scheduledCleanup() {
        cleanupOrphans()
    }

    /**
     * Scans the bucket, deletes unreferenced objects older than the grace window, and returns the
     * number deleted. Extracted from the scheduled entry point so tests can invoke it directly.
     */
    fun cleanupOrphans(): Int {
        log.info("Orphan cleanup job starting")

        // Snapshot the DB references first. Ordering matters: reading references before listing S3
        // means any object uploaded after this read is newer than the cutoff anyway, so a
        // reference we might have missed can only belong to an object the grace window protects.
        val referencedKeys = HashSet<String>()
        referencedKeys.addAll(pintLogRepository.findAllPhotoKeys())
        referencedKeys.addAll(userRepository.findAllAvatarKeys())

        val cutoff = Instant.now().minus(graceMinutes, ChronoUnit.MINUTES)

        var deleted = 0
        for (obj in s3Service.listAllObjects()) {
            if (obj.key in referencedKeys) continue          // still referenced — keep
            if (obj.lastModified.isAfter(cutoff)) continue   // too fresh — may be mid-flight upload
            try {
                s3Service.deleteObject(obj.key)
                deleted++
                log.info("Deleted orphaned S3 object '{}'", obj.key)
            } catch (e: Exception) {
                // Isolate one object's failure; the next run will retry it.
                log.warn("Failed to delete orphaned S3 object '{}'; will retry next run", obj.key, e)
            }
        }

        log.info("Orphan cleanup job done: {} objects deleted", deleted)
        return deleted
    }
}
