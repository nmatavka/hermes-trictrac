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

    @Test
    fun pouleFixtureCarriesQueueAndViewerMetadata() {
        val snapshot = fixture("trictrac-en-poule-waiting.json")

        assertEquals("trictrac_en_poule", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("trictrac_classique", snapshot.getAsJsonObject("variant").get("active_variant_id").asString)
        assertEquals("waiting_for_queue_refill", snapshot.get("status").asString)
        assertEquals("spectator", snapshot.getAsJsonObject("viewer").get("role").asString)
        assertTrue(snapshot.getAsJsonObject("viewer").get("can_claim_queue_spot").asBoolean)
        assertEquals("growing_pot", snapshot.getAsJsonObject("poule").get("style").asString)
        assertEquals(1, snapshot.getAsJsonObject("poule").get("open_queue_slots").asInt)
    }

    @Test
    fun pluckedPouleFixtureCarriesFixedFundConfig() {
        val snapshot = fixture("trictrac-en-poule-plumee.json")
        val config = snapshot.getAsJsonObject("poule").getAsJsonObject("config")

        assertEquals("trictrac_en_poule_plumee", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("plucked_pot", snapshot.getAsJsonObject("poule").get("style").asString)
        assertEquals(100, config.get("stake").asInt)
        assertEquals(5, config.get("hole_value").asInt)
        assertEquals(300, snapshot.getAsJsonObject("poule").get("pool").asInt)
        assertEquals("queued", snapshot.getAsJsonObject("viewer").get("role").asString)
    }

    @Test
    fun poulePlayingFixtureCarriesActiveViewerAndGrowingPotConfig() {
        val snapshot = fixture("trictrac-en-poule-playing.json")
        val config = snapshot.getAsJsonObject("poule").getAsJsonObject("config")

        assertEquals("playing", snapshot.get("status").asString)
        assertEquals("active", snapshot.getAsJsonObject("viewer").get("role").asString)
        assertEquals("growing_pot", snapshot.getAsJsonObject("poule").get("style").asString)
        assertEquals(7, config.get("ante").asInt)
        assertEquals(3, config.get("win_target").asInt)
        assertEquals(21, snapshot.getAsJsonObject("poule").get("pool").asInt)
    }

    @Test
    fun multiplayerOrderDrawFixtureCarriesBenchViewerAndRollAuthority() {
        val snapshot = fixture("trictrac-aecrire-chouette-awaiting-order-draw.json")
        val multiplayer = snapshot.getAsJsonObject("multiplayer")

        assertEquals("trictrac_aecrire_chouette", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("trictrac_aecrire", snapshot.getAsJsonObject("variant").get("active_variant_id").asString)
        assertEquals("awaiting_order_draw", snapshot.get("status").asString)
        assertTrue(snapshot.getAsJsonObject("ui_actions").get("can_roll_for_order").asBoolean)
        assertEquals("bench", snapshot.getAsJsonObject("viewer").get("role").asString)
        assertEquals("associates", multiplayer.getAsJsonObject("order_draw").get("step").asString)
        assertEquals("jane", multiplayer.getAsJsonObject("order_draw").getAsJsonObject("current_roller").get("name").asString)
    }

    @Test
    fun multiplayerConsentFixtureCarriesParticipantResponses() {
        val snapshot = fixture("trictrac-aecrire-chouette-awaiting-match-options.json")
        val pendingOptions = snapshot.getAsJsonObject("pending_match_options")

        assertEquals("awaiting_match_options", snapshot.get("status").asString)
        assertEquals("multiplayer_partie_length_consent", pendingOptions.get("kind").asString)
        assertEquals(3, pendingOptions.getAsJsonArray("participants").size())
        assertEquals("12", pendingOptions.getAsJsonObject("responses").get("1").asString)
        assertTrue(snapshot.getAsJsonObject("ui_actions").get("can_submit_match_options").asBoolean)
    }

    @Test
    fun aTournerPlayingFixtureCarriesPlayerLedger() {
        val snapshot = fixture("trictrac-aecrire-a-tourner-playing.json")
        val players = snapshot.getAsJsonObject("multiplayer").getAsJsonObject("ledger").getAsJsonArray("players")

        assertEquals("trictrac_aecrire_a_tourner", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("playing", snapshot.get("status").asString)
        assertEquals(3, players.size())
        assertEquals("bob", players[2].asJsonObject.get("name").asString)
        assertEquals(3, players[2].asJsonObject.get("resting_consolation").asInt)
    }

    @Test
    fun combineContinuationFixtureCarriesBasketState() {
        val snapshot = fixture("trictrac-combine-chouette-continuing.json")
        val combinePoule =
            snapshot.getAsJsonObject("multiplayer").getAsJsonObject("ledger").getAsJsonObject("combine_poule")

        assertEquals("trictrac_combine_chouette", snapshot.getAsJsonObject("variant").get("id").asString)
        assertEquals("continuing_honneurs_after_coup", snapshot.get("status").asString)
        assertEquals(8, combinePoule.get("basket").asInt)
        assertEquals("white", combinePoule.get("contract_side").asString)
    }

    private fun fixture(name: String): JsonObject =
        JsonParser.parseString(fixturesDir.resolve(name).readText()).asJsonObject
}
