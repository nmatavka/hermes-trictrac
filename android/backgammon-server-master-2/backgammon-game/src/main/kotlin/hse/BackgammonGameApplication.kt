package hse

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.cache.annotation.EnableCaching
import org.springframework.cloud.openfeign.EnableFeignClients
import org.springframework.kafka.annotation.EnableKafka

@SpringBootApplication
@EnableCaching
@EnableFeignClients
@EnableKafka
class BackgammonGameApplication

fun main(args: Array<String>) {
    runApplication<BackgammonGameApplication>(*args)
}
