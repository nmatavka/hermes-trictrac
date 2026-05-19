package hse.dto

import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.*

data class EmitterDto(
    val userId: Int,
    val emitter: SseEmitter
) {
    override fun hashCode(): Int {
        return Objects.hash(userId)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EmitterDto

        return userId == other.userId
    }
}