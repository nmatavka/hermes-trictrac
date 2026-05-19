package utils

fun String.trimLines() = trim().lines().map(String::trim).filter {it != ""}