package com.pintking.api.user

import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface UserRepository : JpaRepository<UserEntity, UUID> {
    fun findByAppleId(appleId: String): UserEntity?
}
