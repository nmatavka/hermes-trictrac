package hse.producer

import com.fasterxml.jackson.databind.ObjectMapper
import kafka.GameEndMessage
import org.springframework.beans.factory.annotation.Value
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Component

@Component
class GameEndMessageProducer(
    private val kafkaTemplate: KafkaTemplate<String, String>,
    private val objectMapper: ObjectMapper,
    @Value("\${kafka.topic.narde.event.game-end}")
    private var topic: String
) {
    fun sendMessage(gameEndMessage: GameEndMessage) {
        kotlin.runCatching {
            kafkaTemplate.send(topic, objectMapper.writeValueAsString(gameEndMessage))
        }
    }
}