package com.hermes.trictrac.android.ui

import com.google.gson.Gson
import java.nio.file.Path
import kotlin.io.path.readText
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class GameSnapshotParsingTest {
    private val gson = Gson()

    @Test
    fun parsesPouleSnapshotIntoTypedViewerAndQueueState() {
        val snapshot = fixture("trictrac-en-poule-waiting.json")

        assertEquals("trictrac_en_poule", snapshot.variant.id)
        assertEquals("trictrac_classique", snapshot.variant.activeVariantId)
        assertEquals("spectator", snapshot.viewer?.role)
        assertTrue(snapshot.viewer?.canClaimQueueSpot == true)
        assertEquals("growing_pot", snapshot.poule?.style)
        assertEquals(1, snapshot.poule?.openQueueSlots)
        assertEquals("open_slot", snapshot.poule?.queue?.firstOrNull()?.kind)
    }

    @Test
    fun parsesAllSessionViewerRolesAcrossFixtures() {
        val spectator = fixture("trictrac-en-poule-waiting.json")
        val queued = fixture("trictrac-en-poule-plumee.json")
        val active = fixture("trictrac-en-poule-playing.json")
        val bench = fixture("trictrac-aecrire-chouette-awaiting-order-draw.json")

        assertEquals("spectator", spectator.viewer?.role)
        assertEquals("queued", queued.viewer?.role)
        assertEquals("active", active.viewer?.role)
        assertEquals("bench", bench.viewer?.role)
    }

    @Test
    fun parsesMultiplayerOrderDrawSnapshotIntoTypedSessionState() {
        val snapshot = fixture("trictrac-aecrire-chouette-awaiting-order-draw.json")

        assertEquals("trictrac_aecrire", snapshot.variant.activeVariantId)
        assertEquals("bench", snapshot.viewer?.role)
        assertTrue(snapshot.uiActions.canRollForOrder)
        assertEquals("associates", snapshot.multiplayer?.orderDraw?.step)
        assertEquals("jane", snapshot.multiplayer?.orderDraw?.currentRoller?.name)
        assertFalse(snapshot.multiplayer?.awaitingMatchOptions ?: true)
    }

    @Test
    fun parsesMultiplayerConsentResponsesByParticipantId() {
        val snapshot = fixture("trictrac-aecrire-chouette-awaiting-match-options.json")

        assertEquals("multiplayer_partie_length_consent", snapshot.pendingMatchOptions?.kind)
        assertEquals("12", snapshot.pendingMatchOptions?.defaultChoice)
        assertEquals("nick", snapshot.pendingMatchOptions?.participants?.firstOrNull()?.name)
        assertEquals("12", snapshot.pendingMatchOptions?.responses?.get("1"))
        assertEquals(null, snapshot.pendingMatchOptions?.responses?.get("2"))
    }

    @Test
    fun parsesATournerLedgerAndRestingPlayer() {
        val snapshot = fixture("trictrac-aecrire-a-tourner-playing.json")
        val ledger = snapshot.multiplayer?.ledger?.players.orEmpty()

        assertEquals("playing", snapshot.multiplayer?.phase)
        assertEquals("bob", snapshot.multiplayer?.rotationState?.resting?.name)
        assertEquals(3, ledger.size)
        assertEquals(21, ledger.first().finalTotal)
        assertEquals(3, ledger.last().restingConsolation)
    }

    @Test
    fun parsesCombineContinuationBasketAndSideLedger() {
        val snapshot = fixture("trictrac-combine-chouette-continuing.json")

        assertEquals("continuing_honneurs_after_coup", snapshot.multiplayer?.phase)
        assertEquals(8, snapshot.multiplayer?.ledger?.combinePoule?.basket)
        assertEquals("white", snapshot.multiplayer?.ledger?.combinePoule?.contractSide)
        assertEquals(2, snapshot.multiplayer?.ledger?.sides?.size)
        assertEquals(10, snapshot.multiplayer?.ledger?.sides?.firstOrNull()?.basketWon)
    }

    @Test
    fun parsesPluckedPouleFundAndHistory() {
        val snapshot = fixture("trictrac-en-poule-plumee.json")

        assertEquals("plucked_pot", snapshot.poule?.style)
        assertEquals(100, snapshot.poule?.config?.stake)
        assertEquals(5, snapshot.poule?.config?.holeValue)
        assertEquals(300, snapshot.poule?.pool)
        assertNotNull(snapshot.poule?.history?.firstOrNull())
    }

    @Test
    fun parsesGrowingPotPouleConfigAndLedger() {
        val snapshot = fixture("trictrac-en-poule-playing.json")

        assertEquals("growing_pot", snapshot.poule?.style)
        assertEquals(7, snapshot.poule?.config?.ante)
        assertEquals(3, snapshot.poule?.config?.winTarget)
        assertEquals(true, snapshot.poule?.config?.margotEnabled)
        assertEquals("nick", snapshot.poule?.ledger?.firstOrNull()?.name)
        assertEquals(7, snapshot.poule?.ledger?.firstOrNull()?.net)
    }

    private fun fixture(name: String): GameSnapshotDto {
        val resource = checkNotNull(javaClass.classLoader.getResource("fixtures/$name")) {
            "Missing fixture: $name"
        }
        val json = Path.of(resource.toURI()).readText()
        return gson.fromJson(json, GameSnapshotDto::class.java)
    }
}
