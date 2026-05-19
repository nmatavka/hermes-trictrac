package hse.service

import hse.dao.EmitterRuntimeDao
import hse.dto.GameEvent
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.io.IOException

@Service
class EmitterService(
    val emitterRuntimeDao: EmitterRuntimeDao
) {
    private final val logger = LoggerFactory.getLogger(this.javaClass)

    fun create(gameId: Int, userId: Int): SseEmitter {
        return emitterRuntimeDao.add(gameId, userId)
    }

    fun sendEventExceptUser(userId: Int, gameId: Int, event: GameEvent) {
        emitterRuntimeDao.getAllInRoom(gameId)
            .filter { it.userId != userId }
            .forEach { it.emitter.send(event) }
    }

    fun sendForAll(gameId: Int, event: GameEvent) {
        emitterRuntimeDao.getAllInRoom(gameId)
            .forEach { emitterDto ->
                try {
                    emitterDto.emitter.send(event)
                } catch (e: IOException) {
                    emitterRuntimeDao.remove(gameId, emitterDto.userId)
                    logger.warn(e.message)
                }
            }
    }
}