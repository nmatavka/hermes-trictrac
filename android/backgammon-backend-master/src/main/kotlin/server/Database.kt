package server

import app.cash.sqldelight.ColumnAdapter
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.kyleth95.backgammon.BackgammonDatabase
import migrations.Games
import utils.getEnvVar
import java.util.Properties
import kotlin.time.Instant

val sqliteFilename = getEnvVar("SQLITE_FILENAME") ?: "backgammon.db"

val instantAdapter = object : ColumnAdapter<Instant, String> {
    override fun decode(databaseValue: String): Instant {
        return Instant.parse(databaseValue)
    }

    override fun encode(value: Instant): String {
        return value.toString() // This produces an ISO-8601 string
    }
}

val driver: SqlDriver = JdbcSqliteDriver(
    "jdbc:sqlite:$sqliteFilename", Properties()
)

val Database = BackgammonDatabase.invoke(
    driver, gamesAdapter = Games.Adapter(
        created_atAdapter = instantAdapter,
        last_move_atAdapter = instantAdapter
    )
)