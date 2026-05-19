package hse.menu.dto

import org.springframework.beans.factory.config.BeanDefinition.SCOPE_SINGLETON
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

@Component
@Scope(SCOPE_SINGLETON)
data class ConnectQueueHolder(
    val connectionQueues: ConcurrentHashMap<GameSearchDetails, ConcurrentLinkedQueue<ConnectionDto>> = ConcurrentHashMap()
)