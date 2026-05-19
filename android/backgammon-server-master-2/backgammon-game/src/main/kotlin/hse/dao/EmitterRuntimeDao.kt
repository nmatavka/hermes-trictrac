package hse.dao

import hse.dto.EmitterDto
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.beans.factory.config.ConfigurableBeanFactory
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Component
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet

@Component
@Scope(ConfigurableBeanFactory.SCOPE_SINGLETON)
class EmitterRuntimeDao(
    private val emitters: ConcurrentHashMap<Int, MutableSet<EmitterDto>> = ConcurrentHashMap(),
    @Value("\${config.sse.time-out}") private val sseTimeOut: Long
) {

    val logger: Logger = LoggerFactory.getLogger(this.javaClass)

    @Synchronized
    fun add(gameId: Int, userId: Int): SseEmitter {
        if (!emitters.containsKey(gameId)) {
            emitters[gameId] = CopyOnWriteArraySet()
        }
        val emitter = SseEmitter(0)
        emitter.onCompletion { remove(gameId, userId) }
        emitter.onError { remove(gameId, userId) }
        emitter.onTimeout { remove(gameId, userId) }
        val emitterCollection = emitters[gameId]!!
        val dtoToSave = EmitterDto(userId, emitter)
        emitterCollection.remove(dtoToSave)
        emitterCollection.add(dtoToSave)
        logger.info("добавлен emitter game: $gameId, user: $userId, timeout $sseTimeOut")
        return emitter
    }

    @Synchronized
    fun remove(gameId: Int, userId: Int) {
        emitters[gameId]?.removeIf { it.userId == userId }
    }

    fun getAllInRoom(gameId: Int): Set<EmitterDto> {
        return emitters[gameId] ?: HashSet()
    }
}