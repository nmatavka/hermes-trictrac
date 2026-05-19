package gnubg

import kotlinx.serialization.Serializable
import utils.Filename
import utils.HasFilename
import utils.getEnvVar
import java.util.UUID

val gamesFolder = getEnvVar("GAMES_FOLDER") ?: "games"

@Serializable @JvmInline value class ServerMatchId(val serverMatchId: String): HasFilename {
    override val filename get() = Filename("${gamesFolder}/$serverMatchId.mat")
    companion object {
        fun new() = ServerMatchId(UUID.randomUUID().toString())
    }
}