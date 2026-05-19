package hse.playerservice.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.time.Clock

@Configuration
class BeanConfig {


    @Bean
    fun clock(): Clock {
        return Clock.systemUTC()
    }
}