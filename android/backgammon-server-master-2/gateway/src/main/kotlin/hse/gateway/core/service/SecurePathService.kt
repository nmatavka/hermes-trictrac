package hse.gateway.core.service

import hse.gateway.core.constant.LOGIN
import hse.gateway.core.constant.REGISTER
import hse.gateway.core.constant.USERINFO
import hse.gateway.core.dto.AllowedMethods
import org.springframework.http.HttpMethod
import org.springframework.stereotype.Service

@Service
class SecurePathService {
    companion object {
        val unsecuredUrls = mapOf(
            LOGIN to AllowedMethods.allowAll(),
            REGISTER to AllowedMethods.allowAll(),
            USERINFO to AllowedMethods.getOnly(),
        )
    }

    fun isSecure(path: String, method: HttpMethod): Boolean {
        val secureCheck = unsecuredUrls[path] ?: return true
        val result = !secureCheck.methods.contains(method)
        return if (secureCheck.invert) {
            !result
        } else {
            result
        }
    }
}