package com.joris.Backgammon.dto

data class LoginRequest(
    val email : String,
    val password : String,
)

data class RegisterRequest(
    val email : String,
    val password : String
)
