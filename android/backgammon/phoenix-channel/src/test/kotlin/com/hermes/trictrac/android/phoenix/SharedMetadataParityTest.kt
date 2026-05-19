package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.nio.file.Files
import java.nio.file.Path
import kotlin.io.path.readText
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SharedMetadataParityTest {
    private val repoRoot: Path =
        Path.of("/Users/nick/backgammon")
    private val generatedDir: Path = repoRoot.resolve("shared/ui/generated")

    @Test
    fun languageCatalogMatchesExpectedLocales() {
        val languages = JsonParser.parseString(generatedDir.resolve("language-options.json").readText())
            .asJsonArray
            .map { it.asJsonObject.get("id").asString }

        assertEquals(listOf("en", "de", "fr", "sv", "da"), languages)
    }

    @Test
    fun variantTitlesExposeTheSameKeysForEveryLocale() {
        val titles = JsonParser.parseString(generatedDir.resolve("variant-titles.json").readText())
            .asJsonObject

        val expectedKeys = titles.getAsJsonObject("en").entrySet().map { it.key }.toSet()
        assertTrue(expectedKeys.isNotEmpty())

        titles.entrySet().forEach { (languageId, element) ->
            val localizedKeys = element.asJsonObject.entrySet().map { it.key }.toSet()
            assertEquals(expectedKeys, localizedKeys, "variant keys for $languageId")
        }
    }

    @Test
    fun soundPacksShareCueIdsAndDefaultPackExists() {
        val soundCatalog = JsonParser.parseString(generatedDir.resolve("sound-packs.json").readText())
            .asJsonObject
        val defaultPackId = soundCatalog.get("defaultPackId").asString
        val packs = soundCatalog.getAsJsonArray("packs").map { it.asJsonObject }

        val defaultPack = packs.firstOrNull { it.get("id").asString == defaultPackId }
        assertTrue(defaultPack != null, "default sound pack should exist")

        val expectedCueIds = defaultPack!!.getAsJsonObject("cues").entrySet().map { it.key }.toSet()
        assertTrue(expectedCueIds.isNotEmpty())

        packs.forEach { pack ->
            val cueIds = pack.getAsJsonObject("cues").entrySet().map { it.key }.toSet()
            assertEquals(expectedCueIds, cueIds, "cue ids for ${pack.get("id").asString}")
        }
    }
}
