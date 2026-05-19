package com.joris.Backgammon.Controller


import com.joris.Backgammon.dto.RegisterRequest
import com.joris.Backgammon.dto.User
import com.joris.Backgammon.dto.LoginRequest

import com.joris.Backgammon.service.UserService
import jakarta.validation.constraints.Null
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.http.HttpHeaders
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1")
class BackgammonController(
    private val userService : UserService
) {
    private val logger = LoggerFactory.getLogger(this::class.java);

    @PostMapping("/register")
    suspend fun registerUser(
        @RequestBody user : User
    )
    : ResponseEntity<String> {
        logger.info("Servicing register request")
        println("Register request")
        if (!userService.checkUserExists(user.email)){
            val res = userService.registerUser(user);
            if(res == null){
                return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body("Internal Server Error. Try again later")
            }
            return ResponseEntity.status(HttpStatus.CREATED).body("Welcome ${res}. Nice to meet you!")
        }else {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Account already available for user ${user.email}")
        }
    }

    @PostMapping("/login")
    suspend fun loginUser(
        @RequestBody loginData : LoginRequest
    ) : ResponseEntity<String> {

        if(userService.checkUserExists(email = loginData.email)){
            val sessionId = userService.loginUser(email = loginData.email, password = loginData.password)

            if (sessionId == null){
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Please try again soon!")
            }

            val cookie = ResponseCookie.from("session", sessionId!!)
                .httpOnly(true) //
                .path("/") // for every request
                .maxAge(60 * 60 * 3) // set the expiry date
                .build()


            return ResponseEntity
                .status(HttpStatus.OK)
                .header("Set-Cookie", cookie.toString())
                .body("Login successful")

        }else{
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("User with ${loginData.email} not found")
        }

    }

}
