package com.example.database.users

import kotlinx.serialization.Serializable
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction


object Users: Table() {
    private val login = Users.varchar("login", 25)
    private val password = Users.varchar("password", 75)
    private val wins = Users.integer("wins")

    fun insert(userDTO: UserDTO) {
        transaction {
            Users.insert {
                it[login] = userDTO.login
                it[password] = userDTO.password
                it[wins] = 0
            }
        }
    }

    fun fetchUser(login: String): UserDTO? {
        return try {
            transaction {
                val userModel = Users.select { Users.login.eq(login) }.single()
                UserDTO(
                    login = userModel[Users.login],
                    password = userModel[password]
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    fun updateScore(login: String) {
        transaction {
            Users.update({ Users.login eq login }) {
                with(SqlExpressionBuilder) {
                    it.update(wins, wins + 1)
                }
            }
        }
    }

    @Serializable
    data class Leader(val login: String, val wins: Int)

    fun fetchLeaders(): List<Leader> {
        return transaction {
            exec("""
            SELECT login, wins FROM (
                SELECT login, wins FROM users ORDER BY wins DESC
            ) WHERE ROWNUM <= 5
        """.trimIndent()) { rs ->
                val result = mutableListOf<Leader>()
                while (rs.next()) {
                    result.add(Leader(rs.getString("login"), rs.getInt("wins")))
                }
                result
            } ?: emptyList()
        }
    }
}