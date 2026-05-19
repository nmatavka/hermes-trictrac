package hse.gateway.core.dto

import org.springframework.http.HttpMethod

class AllowedMethods(
    val methods: Set<HttpMethod>,
    val invert: Boolean = false
) {
    companion object {
        fun allowAll(): AllowedMethods {
            return AllowedMethods(setOf(), true)
        }

        fun getOnly(): AllowedMethods {
            return AllowedMethods(setOf(HttpMethod.GET))
        }
    }
}