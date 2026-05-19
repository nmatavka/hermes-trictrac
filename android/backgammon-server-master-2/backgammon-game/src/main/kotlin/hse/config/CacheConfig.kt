package hse.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.cache.annotation.CachingConfigurer
import org.springframework.cache.interceptor.CacheErrorHandler
import org.springframework.cache.interceptor.LoggingCacheErrorHandler
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import redis.clients.jedis.Jedis

@Configuration
class CacheConfig: CachingConfigurer {

    @Bean
    fun jedisConfiguration(
        @Value("\${config.jedis.host}") host: String,
        @Value("\${config.jedis.port}") port: Int
    ): Jedis? {
        return  null
//        return try {
//            JedisPool(host, port).resource
//        } catch (_: RuntimeException) {
//            null
//        }
    }

    override fun errorHandler(): CacheErrorHandler? = LoggingCacheErrorHandler(true)
}