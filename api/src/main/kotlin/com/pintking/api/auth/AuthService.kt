package com.pintking.api.auth

import com.pintking.api.user.UserEntity
import com.pintking.api.user.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class AuthService(
    private val appleTokenVerifier: AppleTokenVerifier,
    private val jwtService: JwtService,
    private val refreshTokenService: RefreshTokenService,
    private val userRepository: UserRepository
) {

    @Transactional
    fun authenticateWithApple(identityToken: String): AuthResponse {
        val appleId = appleTokenVerifier.verify(identityToken)

        val existingUser = userRepository.findByAppleId(appleId)
        val isNewUser = existingUser == null

        val user = existingUser ?: userRepository.save(
            UserEntity(
                appleId = appleId,
                displayName = "User"
            )
        )

        val jwt = jwtService.generateToken(user.id!!)
        val refreshToken = refreshTokenService.generateRefreshToken(user.id!!)

        return AuthResponse(
            jwt = jwt,
            refreshToken = refreshToken,
            isNewUser = isNewUser
        )
    }

    fun refresh(rawRefreshToken: String): TokenPair {
        val userId = refreshTokenService.rotateToken(rawRefreshToken)
        val jwt = jwtService.generateToken(userId)
        val newRefreshToken = refreshTokenService.generateRefreshToken(userId)
        return TokenPair(jwt = jwt, refreshToken = newRefreshToken)
    }
}
