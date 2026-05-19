package hse.menu.consumer

import com.fasterxml.jackson.databind.ObjectMapper
import hse.menu.service.GameService
import kafka.GameEndMessage
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional

@Component
class GameEndMessageConsumer(
    private val gameService: GameService,
    private val objectMapper: ObjectMapper,
) {
    @Transactional
    @KafkaListener(topics = ["\${kafka.topic.narde.event.game-end}"], groupId = "\${spring.kafka.consumer.group-id}")
    fun consume(data: String) {
        val gameEndMessage = objectMapper.readValue(data, GameEndMessage::class.java)
        gameService.handleGameEnd(gameEndMessage)
    }
}