package hse.adapter

import org.springframework.stereotype.Component
import redis.clients.jedis.Jedis

@Component
class RedisAdapter(
    private val jedis: Jedis?
) {

    fun del(id: String): Long {
        return jedis?.del(id) ?: -1
    }

    fun exists(id: String): Boolean {
        return jedis?.exists(id) ?: false
    }

    fun get(id: String): String? {
        return jedis?.get(id)
    }

    fun setex(id: String, value: String) {
        jedis?.setex(id, 300, value)
    }

    fun rpush(id: String, value: String) {
        jedis?.rpush(id, value)
        expire(id)
    }

    fun lrange(id: String): MutableList<String>? {
        return jedis?.lrange(id, 0, -1)
    }

    fun popLast(id: String): String? {
        return jedis?.rpop(id, 1)?.firstOrNull()
    }

    fun expire(id: String) {
        jedis?.expire(id, 300)
    }
}