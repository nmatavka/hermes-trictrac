package hse.menu.service

import hse.menu.dto.SseEventDto
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.config.ConfigurableBeanFactory.SCOPE_SINGLETON
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Service
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.concurrent.ConcurrentHashMap

@Service
@Scope(SCOPE_SINGLETON)
class SseEmitterService(
    private val sseEmitters: MutableMap<Long, SseEmitter> = ConcurrentHashMap()
) {
    private val logger = LoggerFactory.getLogger(SseEmitterService::class.java)

    fun subscribe(userId: Long): SseEmitter {
        if (sseEmitters.containsKey(userId)) {
            return sseEmitters[userId]!!
        }
        val sseEmitter = SseEmitter(-1)
        sseEmitter.onCompletion { sseEmitters.remove(userId) }
        sseEmitter.onError { sseEmitters.remove(userId) }
        sseEmitter.onTimeout { sseEmitters.remove(userId) }
        sseEmitters[userId] = sseEmitter
        return sseEmitter
    }

    fun send(sseEventDto: SseEventDto, users: List<Long>) {
        users.forEach {
            logger.info("Sending event $sseEventDto to $it")
            sseEmitters[it]?.send(sseEventDto)
        }
    }
}