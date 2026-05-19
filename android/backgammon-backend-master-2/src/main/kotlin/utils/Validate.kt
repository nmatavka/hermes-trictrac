package com.example.utils

fun validateLogin(login: String): Boolean {
    if (login.length !in 3..25) {
        return false
    }

    val regex = "^[a-zA-Z0-9]+$".toRegex()
    return regex.matches(login)
}

fun validatePassword(password: String): Boolean {
    return password.length in 8..25
}