package com.pintking.api.user

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface UserRepository : JpaRepository<UserEntity, UUID> {
    fun findByAppleId(appleId: String): UserEntity?

    // Orphan cleanup (Task 28): every non-null avatar key currently referenced. Projected to
    // strings so we scan the column, not whole rows, however many users exist.
    @Query("SELECT u.avatarUrl FROM UserEntity u WHERE u.avatarUrl IS NOT NULL")
    fun findAllAvatarKeys(): List<String>
}
