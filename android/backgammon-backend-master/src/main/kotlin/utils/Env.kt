package utils

import io.github.cdimascio.dotenv.dotenv

val dotenvInstance = dotenv {
    ignoreIfMissing = true // Critical for production!
}

fun getEnvVar(name: String): String? {
    return dotenvInstance[name] ?: System.getenv(name)
}