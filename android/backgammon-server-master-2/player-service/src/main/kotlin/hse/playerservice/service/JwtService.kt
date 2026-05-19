package hse.playerservice.service

import hse.playerservice.entity.User
import io.jsonwebtoken.Claims
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.security.Keys
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.*


@Service
class JwtService(
    @Value("\${jwt.secret}") val secret: String,
    @Value("\${jwt.expire}") val expireTime: Long
) {
    private final val key = Keys.hmacShaKeyFor(secret.toByteArray(StandardCharsets.UTF_8))


    fun generateToken(user: User): String {
        return createToken(user.id, user.login)
    }

    fun validateToken(token: String): Boolean {
        val claims = extractAllClaims(token)
        return !isExpired(claims.expiration)
    }

    fun extractLogin(token: String): String {
        return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).payload.subject
    }

    fun extractUserId(token: String): String {
        return Jwts.parser().verifyWith(key).build().parseSignedClaims(token).payload.id
    }

    fun refreshToken(token: String): String {
        val claims = extractAllClaims(token)
        return createToken(claims.id.toLong(), claims.subject)
    }

    private fun isExpired(date: Date): Boolean {
        return date.before(Date.from(Instant.now()))
    }

    private fun extractAllClaims(token: String): Claims {
        return Jwts
            .parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .payload
    }

    private fun createToken(id: Long, login: String): String {
        val now = Instant.now()
        val expiresAt = now.plusSeconds(expireTime)

        return Jwts.builder()
            .subject(login)
            .id(id.toString())
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiresAt))
            .signWith(key).compact();
    }
}