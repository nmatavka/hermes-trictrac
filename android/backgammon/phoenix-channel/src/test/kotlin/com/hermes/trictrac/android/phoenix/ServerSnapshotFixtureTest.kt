package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.nio.file.Path
import kotlin.io.path.readText
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ServerSnapshotFixtureTest {
    private val fixturesDir =
        Path.of("/Users/nick/backgammon/android/backgammon/app/src/test/resources/fixtures")

    @Test
    fun backgammonOpeningFixtureMatchesExpectedContract() {
        val snapshot = fixture("backgammon-opening.json")

        assertEquals("backgammon", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("playing", snapshot.get("status").asString)
        assertNotNull(snapshot.getAsJsonObject("opening_roll"))
        assertTrue(snapshot.getAsJsonArray("legal_moves").isEmpty)
        assertTrue(snapshot.getAsJsonObject("ui_actions").get("can_roll").asBoolean)
    }

    @Test
    fun trictracPregameFixtureCarriesPendingOptions() {
        val snapshot = fixture("trictrac-aecrire-pregame.json")
        val pendingOptions = snapshot.getAsJsonObject("pending_match_options")

        assertEquals("trictrac_aecrire", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("awaiting_match_options", snapshot.get("status").asString)
        assertEquals("trictrac_partie_length_consent", pendingOptions.get("kind").asString)
        assertTrue(snapshot.getAsJsonObject("ui_actions").get("can_submit_match_options").asBoolean)
        assertNotNull(snapshot.getAsJsonObject("trictrac"))
    }

    private fun fixture(name: String): JsonObject =
        JsonParser.parseString(fixturesDir.resolve(name).readText()).asJsonObject
}
