package com.example.features.register

import com.example.database.tokens.TokenDTO
import com.example.database.tokens.Tokens
import com.example.database.users.UserDTO
import com.example.database.users.Users
import com.example.utils.validateLogin
import com.example.utils.validatePassword
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import org.jetbrains.exposed.exceptions.ExposedSQLException
import org.mindrot.jbcrypt.BCrypt
import java.util.*

class RegisterController (private val call: ApplicationCall) {

    suspend fun registerNewUser() {
        val registerReceiveRemote = call.receive<RegisterReceiveRemote>()
        val isLoginValid = validateLogin(registerReceiveRemote.login)
        val isPasswordValid = validatePassword(registerReceiveRemote.password)
        val hashedPassword = BCrypt.hashpw(registerReceiveRemote.password, BCrypt.gensalt())
        val userDTO = Users.fetchUser(registerReceiveRemote.login)
        if (!isLoginValid) {
            call.respond(HttpStatusCode.BadRequest, "Login must be 3 to 25 symbols long and contain only latin letters and numbers")
        }
        else if (!isPasswordValid) {
            call.respond(HttpStatusCode.BadRequest, "Password must be 8 to 25 symbols long")
        }
        else if (userDTO != null) {
            call.respond(HttpStatusCode.Conflict, "User already exists")
        } else {
            val token = UUID.randomUUID().toString()
            try {
                Users.insert(
                    UserDTO(
                        login = registerReceiveRemote.login,
                        password = hashedPassword
                    )
                )
                Tokens.insert(
                    TokenDTO(
                        login = registerReceiveRemote.login,
                        token = token
                    )
                )
                call.respond(RegisterResponseRemote(token = token))
            } catch (e: ExposedSQLException) {
                call.respond(HttpStatusCode.Conflict, "User already exists")
            } catch (e: Exception) {
                call.respond(HttpStatusCode.BadRequest, "Can't create user ${e.localizedMessage}")
            }
        }
    }
}