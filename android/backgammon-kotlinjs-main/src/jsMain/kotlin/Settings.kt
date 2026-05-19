import kotlinx.browser.localStorage
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json


@Serializable
enum class PlayerSide {
    PLAYER1, PLAYER2, RANDOM
}

/**
 * Game settings set by the player on the home screen.
 */
@Serializable
class Settings {
    var maxScore: Int = 1
    var level: Int = 1
    var color: PlayerSide = PlayerSide.RANDOM
}

fun loadSettings(): Settings {
    val loaded = localStorage.getItem("settings")
    val settingsVersion = localStorage.getItem("settings_version")
    if (settingsVersion != VERSION) return Settings()
    return loaded?.let {Json.decodeFromString(it)} ?: Settings()
}

fun saveSettings(settings: Settings) {
    localStorage.setItem("settings", Json.encodeToString(settings))
    localStorage.setItem("settings_version", VERSION)
}

