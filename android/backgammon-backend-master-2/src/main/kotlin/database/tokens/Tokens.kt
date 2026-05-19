package com.example.database.tokens

import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction


object Tokens: Table() {
    private val login = Tokens.varchar("login", 25)
    private val token = Tokens.varchar("token", 50)

    fun insert(tokenDTO: TokenDTO) {
        transaction {
            Tokens.insert {
                it[login] = tokenDTO.login
                it[token] = tokenDTO.token
            }
        }
    }
    fun fetchTokens(login: String): List<String> {
        return try {
            transaction {
                Tokens.select { Tokens.login.eq(login) }.toList()
                    .map { it[token]
                    }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
    fun deleteToken(tokenDTO: TokenDTO) {
        transaction {
            Tokens.deleteWhere(null, null) { token.eq(tokenDTO.token) }
        }
    }
}

