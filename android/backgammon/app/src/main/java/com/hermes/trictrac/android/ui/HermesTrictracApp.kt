package com.hermes.trictrac.android.ui

import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.icu.text.MessageFormat
import android.media.MediaPlayer
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.hermes.trictrac.android.BuildConfig
import com.hermes.trictrac.android.offline.Dice
import com.hermes.trictrac.android.offline.Game
import com.hermes.trictrac.android.offline.GameState
import com.hermes.trictrac.android.offline.Move
import com.hermes.trictrac.android.offline.Result
import com.hermes.trictrac.android.phoenix.OkHttpPhoenixTransport
import com.hermes.trictrac.android.phoenix.PhoenixChannelClient
import com.hermes.trictrac.android.phoenix.PhoenixReplyException
import com.hermes.trictrac.android.phoenix.PhoenixSocketUrl
import com.hermes.trictrac.android.ui.theme.HermesColors
import java.io.Closeable
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient

private const val PREFS_NAME = "hermes_trictrac_android"
private const val DEFAULT_SERVER_URL = "http://10.0.2.2:4000"
private val COMPUTER_BOTS = mapOf(
    "backgammon" to "backgammon_ai",
    "trictrac_classique" to "trictrac_zero",
    "trictrac_aecrire" to "trictrac_zero",
    "trictrac_combine" to "trictrac_zero",
    "toc" to "trictrac_zero",
    "toccategli" to "trictrac_zero",
)

@Composable
fun HermesTrictracApp() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val preferences = remember { AppPreferences(context) }
    val gson = remember { Gson() }
    var catalogs by remember { mutableStateOf<SharedCatalogs?>(null) }
    var destination by rememberSaveable { mutableStateOf(AppDestination.Lobby) }
    var settings by remember {
        mutableStateOf(preferences.loadSettings())
    }
    var lobby by remember {
        mutableStateOf(preferences.loadLobby())
    }
    var onlineState by remember { mutableStateOf(OnlineTableState()) }
    var localState by remember { mutableStateOf(LocalTableState()) }
    var onlineSession by remember { mutableStateOf<OnlineGameSession?>(null) }
    var localSession by remember { mutableStateOf<LocalBackgammonSession?>(null) }
    val soundPlayer = remember(context) { SharedSoundPlayer(context) }

    LaunchedEffect(Unit) {
        catalogs = SharedCatalogs.load(context, gson)
        val defaultPack = catalogs?.soundPacks?.defaultPackId
        if (settings.soundPackId.isBlank() && !defaultPack.isNullOrBlank()) {
            settings = settings.copy(soundPackId = defaultPack)
            preferences.saveSettings(settings)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            scope.launch {
                onlineSession?.close()
                localSession?.close()
            }
        }
    }

    val activeCatalogs = catalogs
    if (activeCatalogs == null) {
        SplashScreen()
        return
    }

    val strings = remember(activeCatalogs, settings.languageId) {
        SharedStrings(activeCatalogs, settings.languageId)
    }

    Surface(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    listOf(Color(0xFF2D100B), Color(0xFF180705), Color(0xFF110403)),
                ),
            ),
        color = Color.Transparent,
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                AppHeader(
                    title = strings.text("appTitle"),
                    subtitle = when (destination) {
                        AppDestination.Lobby -> strings.text("lobby.title")
                        AppDestination.Online -> strings.text("game.tableGame")
                        AppDestination.Local -> activeCatalogs.variantTitle(settings.languageId, "backgammon")
                        AppDestination.Settings -> strings.text("language")
                    },
                    showBack = destination != AppDestination.Lobby,
                    onBack = {
                        if (destination == AppDestination.Online) {
                            scope.launch { onlineSession?.close() }
                        }
                        destination = AppDestination.Lobby
                    },
                    onSettings = { destination = AppDestination.Settings },
                )
            },
        ) { innerPadding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .navigationBarsPadding(),
            ) {
                when (destination) {
                    AppDestination.Lobby -> LobbyScreen(
                        strings = strings,
                        catalogs = activeCatalogs,
                        lobby = lobby,
                        settings = settings,
                        onLobbyChange = {
                            lobby = it
                            preferences.saveLobby(it)
                        },
                        onOpenOnline = {
                            scope.launch { onlineSession?.close() }
                            onlineState = OnlineTableState(
                                isJoining = true,
                                lobbyName = lobby.lobbyName,
                                variantId = lobby.variantId,
                            )
                            val session = OnlineGameSession(
                                scope = scope,
                                gson = gson,
                                serverUrl = settings.serverUrl,
                                joinRequest = lobby.toJoinRequest(),
                                onState = { nextState -> onlineState = nextState },
                                onCue = { cue -> soundPlayer.play(activeCatalogs, settings, cue) },
                            )
                            onlineSession = session
                            destination = AppDestination.Online
                            session.start()
                        },
                        onOpenLocal = {
                            localState = LocalTableState()
                            val session = LocalBackgammonSession(
                                onState = { nextState -> localState = nextState },
                                onCue = { cue -> soundPlayer.play(activeCatalogs, settings, cue) },
                            )
                            localSession = session
                            destination = AppDestination.Local
                            session.start()
                        },
                    )

                    AppDestination.Online -> OnlineScreen(
                        strings = strings,
                        catalogs = activeCatalogs,
                        settings = settings,
                        state = onlineState,
                        onSpaceSelected = { move ->
                            onlineSession?.move(move)
                        },
                        onRoll = { onlineSession?.roll() },
                        onUndo = { onlineSession?.undo() },
                        onConfirm = { onlineSession?.confirm() },
                        onReset = { onlineSession?.reset() },
                        onResign = { onlineSession?.resign() },
                        onRemainSeated = { onlineSession?.remainSeated() },
                        onSendChat = { message -> onlineSession?.sendChat(message) },
                        onSubmitOptions = { values -> onlineSession?.submitMatchOptions(values) },
                        onSubmitDecision = { decision -> onlineSession?.submitTurnDecision(decision) },
                    )

                    AppDestination.Local -> LocalScreen(
                        strings = strings,
                        state = localState,
                        onSpaceSelected = { source, target -> localSession?.select(source, target) },
                        onStartOrRoll = { localSession?.startOrRoll() },
                        onUndo = { localSession?.undo() },
                        onReset = { localSession?.resetMatch() },
                    )

                    AppDestination.Settings -> SettingsScreen(
                        strings = strings,
                        catalogs = activeCatalogs,
                        settings = settings,
                        onSettingsChange = {
                            settings = it
                            preferences.saveSettings(it)
                        },
                    )
                }
            }
        }
    }
}

private enum class AppDestination {
    Lobby,
    Online,
    Local,
    Settings,
}

private enum class OpponentChoice {
    HUMAN,
    COMPUTER,
    MARGOT,
}

private data class LobbyDraft(
    val lobbyName: String,
    val userName: String,
    val variantId: String,
    val opponentChoice: OpponentChoice,
) {
    fun toJoinRequest(): JoinRequest {
        val botKind = when (opponentChoice) {
            OpponentChoice.HUMAN -> null
            OpponentChoice.COMPUTER -> COMPUTER_BOTS[variantId]
            OpponentChoice.MARGOT -> COMPUTER_BOTS[variantId]
        }

        return JoinRequest(
            serverLobby = lobbyName.trim().ifEmpty { "mobile-table" },
            userName = userName.trim().ifEmpty { "Android Player" },
            variantId = variantId,
            bot = botKind,
            botMargot = if (opponentChoice == OpponentChoice.MARGOT && botKind != null) "yes" else null,
        )
    }

    companion object {
        val Saver = androidx.compose.runtime.saveable.listSaver<LobbyDraft, String>(
            save = {
                listOf(
                    it.lobbyName,
                    it.userName,
                    it.variantId,
                    it.opponentChoice.name,
                )
            },
            restore = {
                LobbyDraft(
                    lobbyName = it[0],
                    userName = it[1],
                    variantId = it[2],
                    opponentChoice = OpponentChoice.valueOf(it[3]),
                )
            },
        )
    }
}

private data class JoinRequest(
    val serverLobby: String,
    val userName: String,
    val variantId: String,
    val bot: String? = null,
    val botMargot: String? = null,
)

private data class SettingsState(
    val languageId: String,
    val soundEnabled: Boolean,
    val soundPackId: String,
    val serverUrl: String,
) {
    companion object {
        val Saver = androidx.compose.runtime.saveable.listSaver<SettingsState, String>(
            save = {
                listOf(
                    it.languageId,
                    it.soundEnabled.toString(),
                    it.soundPackId,
                    it.serverUrl,
                )
            },
            restore = {
                SettingsState(
                    languageId = it[0],
                    soundEnabled = it[1].toBooleanStrictOrNull() ?: true,
                    soundPackId = it[2],
                    serverUrl = it[3],
                )
            },
        )
    }
}

private class AppPreferences(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun loadLobby(): LobbyDraft = LobbyDraft(
        lobbyName = prefs.getString("lobby_name", "mobile-table") ?: "mobile-table",
        userName = prefs.getString("user_name", "Android Player") ?: "Android Player",
        variantId = prefs.getString("variant_id", "backgammon") ?: "backgammon",
        opponentChoice = runCatching {
            OpponentChoice.valueOf(prefs.getString("opponent_choice", OpponentChoice.HUMAN.name)!!)
        }.getOrElse { OpponentChoice.HUMAN },
    )

    fun saveLobby(lobby: LobbyDraft) {
        prefs.edit()
            .putString("lobby_name", lobby.lobbyName)
            .putString("user_name", lobby.userName)
            .putString("variant_id", lobby.variantId)
            .putString("opponent_choice", lobby.opponentChoice.name)
            .apply()
    }

    fun loadSettings(): SettingsState = SettingsState(
        languageId = prefs.getString("language_id", "en") ?: "en",
        soundEnabled = prefs.getBoolean("sound_enabled", true),
        soundPackId = prefs.getString("sound_pack_id", "") ?: "",
        serverUrl = prefs.getString("server_url", DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL,
    )

    fun saveSettings(settings: SettingsState) {
        prefs.edit()
            .putString("language_id", settings.languageId)
            .putBoolean("sound_enabled", settings.soundEnabled)
            .putString("sound_pack_id", settings.soundPackId)
            .putString("server_url", settings.serverUrl)
            .apply()
    }
}

private data class LanguageOption(val id: String, val label: String)

private data class SoundCueClip(
    val src: String,
    val gain: Double = 1.0,
    val playbackRate: Double = 1.0,
)

private data class SoundPack(
    val id: String,
    val label: String,
    val cues: Map<String, List<SoundCueClip>>,
)

private data class SoundPackCatalog(
    @SerializedName("defaultPackId") val defaultPackId: String,
    val packs: List<SoundPack>,
)

private data class SharedCatalogs(
    val stringsJson: JsonObject,
    val languageOptions: List<LanguageOption>,
    val variantTitlesJson: JsonObject,
    val soundPacks: SoundPackCatalog,
) {
    fun variantOrder(): List<String> {
        return variantTitlesJson.getAsJsonObject("en")?.entrySet()?.map { it.key } ?: emptyList()
    }

    fun variantTitle(languageId: String, variantId: String): String {
        val language = variantTitlesJson.getAsJsonObject(languageId)
            ?: variantTitlesJson.getAsJsonObject("en")
            ?: return variantId
        return language.get(variantId)?.asString ?: variantId
    }

    companion object {
        fun load(context: Context, gson: Gson): SharedCatalogs {
            val strings = JsonParser.parseString(context.assets.readText("strings.json")).asJsonObject
            val variantTitles =
                JsonParser.parseString(context.assets.readText("variant-titles.json")).asJsonObject
            val languageType = object : TypeToken<List<LanguageOption>>() {}.type
            val soundType = object : TypeToken<SoundPackCatalog>() {}.type
            val languages = gson.fromJson<List<LanguageOption>>(
                context.assets.readText("language-options.json"),
                languageType,
            )
            val soundPacks = gson.fromJson<SoundPackCatalog>(
                context.assets.readText("sound-packs.json"),
                soundType,
            )
            return SharedCatalogs(strings, languages, variantTitles, soundPacks)
        }
    }
}

private class SharedStrings(
    private val catalogs: SharedCatalogs,
    private val languageId: String,
) {
    fun text(key: String, args: Map<String, Any> = emptyMap(), fallback: String? = null): String {
        val pattern = lookup(languageId, key) ?: lookup("en", key) ?: fallback ?: humanizeKey(key)
        return if (args.isEmpty()) {
            pattern
        } else {
            MessageFormat(pattern, Locale.forLanguageTag(languageId)).format(args)
        }
    }

    private fun lookup(language: String, key: String): String? {
        var cursor: JsonElement = catalogs.stringsJson.get(language) ?: return null
        key.split('.').forEach { segment ->
            cursor = cursor.asJsonObjectOrNull()?.get(segment) ?: return null
        }
        return cursor.takeIf { it.isJsonPrimitive }?.asString
    }

    private fun humanizeKey(key: String): String =
        key.substringAfterLast('.').replace('_', ' ').replaceFirstChar { it.uppercase() }
}

private class SharedSoundPlayer(private val context: Context) {
    fun play(catalogs: SharedCatalogs, settings: SettingsState, cueId: String) {
        if (!settings.soundEnabled) return

        val pack = catalogs.soundPacks.packs.firstOrNull { it.id == settings.soundPackId }
            ?: catalogs.soundPacks.packs.firstOrNull { it.id == catalogs.soundPacks.defaultPackId }
            ?: return
        val clip = pack.cues[cueId]?.firstOrNull() ?: return
        val assetPath = clip.src
            .removePrefix("../")
            .removePrefix("static/")
            .trimStart('/')

        runCatching {
            val descriptor = context.assets.openFd(assetPath)
            MediaPlayer().apply {
                setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                setVolume(clip.gain.toFloat(), clip.gain.toFloat())
                isLooping = false
                setOnCompletionListener { it.release() }
                prepare()
                start()
            }
        }
    }
}

private sealed interface RulesProvider {
    val id: String
}

private class ServerAuthoritativeRulesProvider : RulesProvider {
    override val id: String = "server-authoritative"
}

private class OfflineBackgammonRulesProvider(
    private val maxScore: Int = 5,
) : RulesProvider {
    override val id: String = "offline-backgammon"
    private var game = Game(maxScore)

    fun game(): Game = game

    fun reset() {
        game = Game(maxScore)
    }

    fun startRoundIfNeeded() {
        if (game.currentRoundResult() == Result.NOT_STARTED || game.currentRoundResult() != Result.RUNNING) {
            if (game.finalGameResult() == Result.NOT_STARTED || game.finalGameResult() == Result.RUNNING) {
                game.startNewRound()
            }
        }
    }

    fun roll() {
        startRoundIfNeeded()
        if (game.currentRoundResult() == Result.RUNNING && game.dice == null) {
            game.rollDice()
        }
    }

    fun undo(): Boolean = game.gameState?.undoLastMove() == true

    fun move(from: Int, to: Int) {
        game.makeMove(from, to)
    }
}

private data class OnlineTableState(
    val isJoining: Boolean = false,
    val lobbyName: String = "",
    val variantId: String = "backgammon",
    val providerId: String = "server-authoritative",
    val game: GameSnapshotDto? = null,
    val playerColor: String? = null,
    val errorMessage: String? = null,
)

private data class LocalTableState(
    val providerId: String = "offline-backgammon",
    val game: Game? = null,
    val board: LocalBoardView? = null,
    val selectedSource: SpaceRef? = null,
    val errorMessage: String? = null,
)

private class OnlineGameSession(
    private val scope: CoroutineScope,
    private val gson: Gson,
    private val serverUrl: String,
    private val joinRequest: JoinRequest,
    private val onState: (OnlineTableState) -> Unit,
    private val onCue: (String) -> Unit,
) {
    private val rulesProvider = ServerAuthoritativeRulesProvider()
    private val okHttpClient = OkHttpClient()
    private var state = OnlineTableState(
        isJoining = true,
        lobbyName = joinRequest.serverLobby,
        variantId = joinRequest.variantId,
        providerId = rulesProvider.id,
    )
    private var channelClient: PhoenixChannelClient? = null
    private var updateSubscription: Closeable? = null

    fun start() {
        emit(state)
        scope.launch(Dispatchers.IO) {
            val topic = "games:${joinRequest.serverLobby}"
            val client = PhoenixChannelClient(
                transportFactory = {
                    OkHttpPhoenixTransport(
                        websocketUrl = PhoenixSocketUrl.build(serverUrl),
                        client = okHttpClient,
                    )
                },
            )
            channelClient = client
            updateSubscription = client.on(topic, "update") { envelope ->
                val payload = envelope.payload.asJsonObjectOrNull() ?: return@on
                val game = payload.get("game") ?: return@on
                val snapshot = gson.fromJson(game, GameSnapshotDto::class.java)
                emit(
                    state.copy(
                        isJoining = false,
                        game = snapshot,
                        errorMessage = null,
                    ),
                )
            }

            val joinPayload = JsonObject().apply {
                addProperty("user", joinRequest.userName)
                addProperty("variant", joinRequest.variantId)
                addProperty("client_id", UUID.randomUUID().toString())
                joinRequest.bot?.let { addProperty("bot", it) }
                joinRequest.botMargot?.let { addProperty("bot_margot", it) }
            }

            runCatching {
                val response = client.join(
                    topic = topic,
                    payload = joinPayload,
                    timeoutMs = if (joinRequest.bot != null) 120_000L else 15_000L,
                ).asJsonObject

                val joinedGame = response.get("game")
                val playerColor = response.get("player")?.asJsonObjectOrNull()?.get("color")?.asString
                val snapshot = joinedGame?.let { gson.fromJson(it, GameSnapshotDto::class.java) }

                emit(
                    state.copy(
                        isJoining = false,
                        playerColor = playerColor,
                        game = snapshot,
                        errorMessage = null,
                    ),
                )
            }.onFailure { error ->
                val message = when (error) {
                    is PhoenixReplyException ->
                        error.response.asJsonObjectOrNull()?.get("msg")?.asString
                            ?: error.response.asJsonObjectOrNull()?.get("reason")?.asString
                            ?: error.message
                    else -> error.message
                } ?: "Unable to join table."

                emit(state.copy(isJoining = false, errorMessage = message))
            }
        }
    }

    fun move(move: LegalMoveDto) {
        push("move", JsonObject().apply {
            add("move", move.toPayload())
        }, cue = "move")
    }

    fun roll() = push("roll", JsonObject(), cue = "roll")
    fun undo() = push("undo", JsonObject(), cue = "undo")
    fun confirm() = push("confirm", JsonObject(), cue = "confirm")
    fun reset() = push("reset", JsonObject(), cue = "turnStart")
    fun resign() = push("resign", JsonObject(), cue = "error")
    fun remainSeated() = push("remain_seated", JsonObject(), cue = "confirm")

    fun sendChat(text: String) {
        push("chat", JsonObject().apply {
            add("chat", JsonObject().apply {
                addProperty("author", state.playerColor ?: "white")
                addProperty("type", "text")
                add("data", JsonObject().apply { addProperty("text", text) })
            })
        }, cue = "chat")
    }

    fun submitMatchOptions(values: Map<String, Any>) {
        push("submit_match_options", JsonObject().apply {
            add("options", values.toJsonObject())
        }, cue = "confirm")
    }

    fun submitTurnDecision(decision: String) {
        push("submit_turn_decision", JsonObject().apply {
            addProperty("decision", decision)
        }, cue = "decision")
    }

    private fun push(event: String, payload: JsonObject, cue: String) {
        val client = channelClient ?: return
        val topic = "games:${joinRequest.serverLobby}"
        scope.launch(Dispatchers.IO) {
            runCatching {
                client.push(topic = topic, event = event, payload = payload)
                onCue(cue)
            }.onFailure { error ->
                val message = if (error is PhoenixReplyException) {
                    error.response.asJsonObjectOrNull()?.get("msg")?.asString ?: error.message
                } else {
                    error.message
                } ?: "Action failed."
                emit(state.copy(errorMessage = message))
            }
        }
    }

    suspend fun close() {
        updateSubscription?.close()
        updateSubscription = null
        channelClient?.disconnect()
        channelClient = null
    }

    private fun emit(next: OnlineTableState) {
        state = next
        scope.launch {
            onState(next)
        }
    }
}

private class LocalBackgammonSession(
    private val onState: (LocalTableState) -> Unit,
    private val onCue: (String) -> Unit,
) {
    private val provider = OfflineBackgammonRulesProvider()
    private var state = LocalTableState(providerId = provider.id)

    fun start() {
        provider.startRoundIfNeeded()
        publish(null)
    }

    fun startOrRoll() {
        provider.roll()
        onCue("roll")
        publish(null)
    }

    fun undo() {
        provider.undo()
        onCue("undo")
        publish(null)
    }

    fun resetMatch() {
        provider.reset()
        provider.startRoundIfNeeded()
        onCue("turnStart")
        publish(null)
    }

    fun select(source: SpaceRef, target: SpaceRef?) {
        val board = state.board ?: return
        if (target == null) {
            publish(source)
            return
        }

        val selectedField = board.fieldForSpace(source) ?: return
        val targetField = board.fieldForSpace(target) ?: return
        runCatching {
            provider.move(selectedField, targetField)
            onCue("move")
            publish(null)
        }.onFailure { error ->
            state = state.copy(errorMessage = error.message ?: "Move failed.")
            onState(state)
        }
    }

    suspend fun close() = Unit

    private fun publish(selected: SpaceRef?) {
        val game = provider.game()
        val board = game.gameState?.let { LocalBoardView.fromGame(it, game) }
        state = LocalTableState(
            providerId = provider.id,
            game = game,
            board = board,
            selectedSource = selected,
            errorMessage = null,
        )
        onState(state)
    }
}

private data class GameSnapshotDto(
    val variant: VariantDto = VariantDto(),
    val status: String = "",
    val players: PlayersDto = PlayersDto(),
    val board: BoardDto = BoardDto(),
    val turn: TurnDto? = null,
    val dice: DiceDto? = null,
    @SerializedName("legal_moves") val legalMoves: List<LegalMoveDto> = emptyList(),
    @SerializedName("last_move") val lastMove: LegalMoveDto? = null,
    @SerializedName("last_moves") val lastMoves: List<LegalMoveDto> = emptyList(),
    @SerializedName("pending_match_options") val pendingMatchOptions: MatchOptionsDto? = null,
    @SerializedName("pending_turn_decision") val pendingTurnDecision: TurnDecisionDto? = null,
    @SerializedName("opening_roll") val openingRoll: OpeningRollDto? = null,
    val match: MatchDto = MatchDto(),
    val trictrac: JsonObject? = null,
    @SerializedName("ui_actions") val uiActions: UiActionsDto = UiActionsDto(),
    val chat: List<ChatMessageDto> = emptyList(),
    val bot: BotDto? = null,
    @SerializedName("seat_reclaim") val seatReclaim: SeatReclaimDto? = null,
)

private data class VariantDto(
    val id: String = "",
    val title: String = "",
    @SerializedName("rule_name") val ruleName: String? = null,
    @SerializedName("active_leg") val activeLeg: ActiveLegDto? = null,
)

private data class ActiveLegDto(val id: String = "", val title: String = "")
private data class PlayersDto(val host: PlayerDto? = null, val guest: PlayerDto? = null)
private data class PlayerDto(val id: String? = null, val name: String? = null, val color: String? = null)
private data class BoardDto(
    val points: List<PointDto> = emptyList(),
    val bar: Map<String, Int> = emptyMap(),
    val outside: Map<String, Int> = emptyMap(),
)

private data class PointDto(val index: Int = 0, val pieces: List<String> = emptyList())
private data class TurnDto(val number: Int = 0, val color: String? = null, @SerializedName("player_name") val playerName: String? = null)
private data class DiceDto(
    val values: List<Int> = emptyList(),
    val moves: List<Int> = emptyList(),
    @SerializedName("moves_left") val movesLeft: List<Int> = emptyList(),
    @SerializedName("moves_played") val movesPlayed: List<LegalMoveDto> = emptyList(),
)

private data class LegalMoveDto(
    @SerializedName("from") val from: JsonElement? = null,
    @SerializedName("to") val to: JsonElement? = null,
    val die: Int? = null,
    val count: Int? = null,
    @SerializedName("dice_used") val diceUsed: List<Int>? = null,
    val sequence: List<JsonElement>? = null,
) {
    fun fromSpace(): SpaceRef = SpaceRef.fromJson(from)
    fun toSpace(): SpaceRef = SpaceRef.fromJson(to)

    fun toPayload(): JsonObject = JsonObject().apply {
        add("from", from?.deepCopy() ?: JsonObject())
        add("to", to?.deepCopy() ?: JsonObject())
        sequence?.takeIf { it.isNotEmpty() }?.let { steps ->
            add("sequence", JsonArray().apply { steps.forEach { add(it) } })
        }
    }
}

private data class MatchOptionsDto(
    val kind: String? = null,
    val prompt: String? = null,
    val choices: List<String> = emptyList(),
    val responses: Map<String, String> = emptyMap(),
    @SerializedName("choiceLabels") val choiceLabels: Map<String, String> = emptyMap(),
    val options: List<OptionDto> = emptyList(),
)

private data class OptionDto(
    val key: String,
    val label: String? = null,
    val prompt: String? = null,
    @SerializedName("defaultValue") val defaultValue: JsonElement? = null,
    val choices: List<OptionChoiceDto> = emptyList(),
)

private data class OptionChoiceDto(
    val value: String,
    val label: String? = null,
)

private data class TurnDecisionDto(
    val key: String? = null,
    val prompt: String? = null,
    val choices: List<String> = emptyList(),
    @SerializedName("actorColor") val actorColor: String? = null,
)

private data class OpeningRollDto(
    val pending: Boolean = false,
    val prompt: String? = null,
    val order: String? = null,
    val rolls: Map<String, Int?> = emptyMap(),
)

private data class MatchDto(
    @SerializedName("is_over") val isOver: Boolean = false,
    val score: Map<String, Int> = emptyMap(),
    val length: Int? = null,
    val winner: String? = null,
    @SerializedName("winner_kind") val winnerKind: String? = null,
    val results: List<JsonObject> = emptyList(),
    val options: JsonObject = JsonObject(),
)

private data class UiActionsDto(
    @SerializedName("can_roll") val canRoll: Boolean = false,
    @SerializedName("can_undo") val canUndo: Boolean = false,
    @SerializedName("can_confirm") val canConfirm: Boolean = false,
    @SerializedName("can_end_turn") val canEndTurn: Boolean = false,
    @SerializedName("end_turn_reason") val endTurnReason: String? = null,
    @SerializedName("end_turn_points") val endTurnPoints: Int? = null,
    @SerializedName("can_submit_match_options") val canSubmitMatchOptions: Boolean = false,
    @SerializedName("can_submit_turn_decision") val canSubmitTurnDecision: Boolean = false,
    @SerializedName("can_reset") val canReset: Boolean = false,
)

private data class ChatMessageDto(
    val author: String? = null,
    val player: String? = null,
    val text: String? = null,
    val data: ChatDataDto? = null,
) {
    fun displayText(): String = data?.text ?: text ?: ""
    fun displayAuthor(playerColor: String?): String = when (author ?: player) {
        null -> "Someone"
        playerColor -> "You"
        else -> author ?: player ?: "Opponent"
    }
}

private data class ChatDataDto(val text: String? = null)
private data class BotDto(val enabled: Boolean = false, val kind: String? = null, val name: String? = null, val color: String? = null)
private data class SeatReclaimDto(
    @SerializedName("seat_color") val seatColor: String? = null,
    @SerializedName("defender_name") val defenderName: String? = null,
    @SerializedName("claimant_name") val claimantName: String? = null,
    @SerializedName("expires_at_ms") val expiresAtMs: Long? = null,
)

private sealed interface SpaceRef {
    data class Point(val index: Int) : SpaceRef
    data object Bar : SpaceRef
    data object Home : SpaceRef
    data class Token(val raw: String) : SpaceRef

    companion object {
        fun fromJson(value: JsonElement?): SpaceRef {
            if (value == null || value.isJsonNull) return Token("")
            if (value.isJsonPrimitive && value.asJsonPrimitive.isNumber) {
                return Point(value.asInt)
            }
            val token = value.asString
            return when (token) {
                "bar" -> Bar
                "home" -> Home
                else -> Token(token)
            }
        }
    }
}

private data class LocalBoardView(
    val turnColor: String,
    val bottomColor: String,
    val points: Map<Int, List<String>>,
    val bar: Map<String, Int>,
    val outside: Map<String, Int>,
    val movable: List<SpaceRef>,
    val targetsBySource: Map<SpaceRef, List<SpaceRef>>,
) {
    fun fieldForSpace(space: SpaceRef): Int? {
        return when (space) {
            is SpaceRef.Point -> space.index + 1
            SpaceRef.Home -> -1
            SpaceRef.Bar -> if (turnColor == "white") 0 else 25
            is SpaceRef.Token -> null
        }
    }

    companion object {
        fun fromGame(state: GameState, game: Game): LocalBoardView {
            val points = (1..24).associate { field ->
                field - 1 to List(state.fields[field]) { if (state.fieldPlayerIdx[field] == 1) "white" else "black" }
            }
            val whiteOnBoard = (0..25).sumOf { index -> if (state.fieldPlayerIdx[index] == 1) state.fields[index] else 0 }
            val blackOnBoard = (0..25).sumOf { index -> if (state.fieldPlayerIdx[index] == 2) state.fields[index] else 0 }
            val movable = state.moveableFields().map { field ->
                when (field) {
                    0, 25 -> SpaceRef.Bar
                    else -> SpaceRef.Point(field - 1)
                }
            }
            val targets = movable.distinct().associateWith { source ->
                val field = when (source) {
                    is SpaceRef.Point -> source.index + 1
                    SpaceRef.Bar -> if (state.turnOf == 1) 0 else 25
                    else -> 0
                }
                state.possibleMovesFrom(field).map { move ->
                    when (move.to) {
                        -1 -> SpaceRef.Home
                        else -> SpaceRef.Point(move.to - 1)
                    }
                }.distinct()
            }
            return LocalBoardView(
                turnColor = if (state.turnOf == 1) "white" else "black",
                bottomColor = "white",
                points = points,
                bar = mapOf("white" to state.fields[0], "black" to state.fields[25]),
                outside = mapOf("white" to (15 - whiteOnBoard), "black" to (15 - blackOnBoard)),
                movable = movable.distinct(),
                targetsBySource = targets,
            )
        }
    }
}

@Composable
private fun SplashScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = HermesColors.Gold)
    }
}

@Composable
private fun AppHeader(
    title: String,
    subtitle: String,
    showBack: Boolean,
    onBack: () -> Unit,
    onSettings: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (showBack) {
                TextButton(onClick = onBack) {
                    Text("Back")
                }
                Spacer(Modifier.width(8.dp))
            }
            Column {
                Text(
                    text = title,
                    style = MaterialTheme.typography.displayMedium,
                    color = HermesColors.Gold,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = HermesColors.Ink.copy(alpha = 0.8f),
                )
            }
        }
        TextButton(onClick = onSettings) {
            Text("Settings")
        }
    }
}

@Composable
private fun LobbyScreen(
    strings: SharedStrings,
    catalogs: SharedCatalogs,
    lobby: LobbyDraft,
    settings: SettingsState,
    onLobbyChange: (LobbyDraft) -> Unit,
    onOpenOnline: () -> Unit,
    onOpenLocal: () -> Unit,
) {
    val selectedBot = lobby.toJoinRequest().bot
    val supportedBot = selectedBot != null

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        HeroCard(
            title = strings.text("lobby.title"),
            body = "${strings.text("lobby.botNote")} ${strings.text("join.connecting")}",
        )

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LabeledField(
                    label = strings.text("lobby.lobbyName"),
                    value = lobby.lobbyName,
                    onValueChange = { onLobbyChange(lobby.copy(lobbyName = it)) },
                )
                LabeledField(
                    label = strings.text("lobby.userName"),
                    value = lobby.userName,
                    onValueChange = { onLobbyChange(lobby.copy(userName = it)) },
                )
                LabeledField(
                    label = "Server URL",
                    value = settings.serverUrl,
                    onValueChange = {},
                    enabled = false,
                )
            }
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(strings.text("lobby.chooseGame"), style = MaterialTheme.typography.titleLarge)
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    catalogs.variantOrder().forEach { variantId ->
                        FilterChip(
                            selected = variantId == lobby.variantId,
                            onClick = { onLobbyChange(lobby.copy(variantId = variantId)) },
                            label = {
                                Text(catalogs.variantTitle(settings.languageId, variantId))
                            },
                        )
                    }
                }
            }
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(strings.text("lobby.playAgainst"), style = MaterialTheme.typography.titleLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OpponentChoice.values().forEach { choice ->
                        FilterChip(
                            selected = choice == lobby.opponentChoice,
                            onClick = { onLobbyChange(lobby.copy(opponentChoice = choice)) },
                            label = {
                                Text(
                                    when (choice) {
                                        OpponentChoice.HUMAN -> strings.text("lobby.human")
                                        OpponentChoice.COMPUTER -> strings.text("lobby.computer")
                                        OpponentChoice.MARGOT -> strings.text("lobby.margot")
                                    },
                                )
                            },
                        )
                    }
                }
                if (!supportedBot && lobby.opponentChoice != OpponentChoice.HUMAN) {
                    Text(
                        text = strings.text("lobby.computerNote"),
                        color = HermesColors.AccentRed,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = onOpenOnline,
                modifier = Modifier.weight(1f),
            ) {
                Text(strings.text("lobby.enter"))
            }
            Button(
                onClick = onOpenLocal,
                modifier = Modifier.weight(1f),
            ) {
                Text("Local Backgammon")
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun OnlineScreen(
    strings: SharedStrings,
    catalogs: SharedCatalogs,
    settings: SettingsState,
    state: OnlineTableState,
    onSpaceSelected: (LegalMoveDto) -> Unit,
    onRoll: () -> Unit,
    onUndo: () -> Unit,
    onConfirm: () -> Unit,
    onReset: () -> Unit,
    onResign: () -> Unit,
    onRemainSeated: () -> Unit,
    onSendChat: (String) -> Unit,
    onSubmitOptions: (Map<String, Any>) -> Unit,
    onSubmitDecision: (String) -> Unit,
) {
    var chatDraft by remember(state.game?.chat?.size) { mutableStateOf("") }
    val game = state.game

    if (state.isJoining && game == null) {
        SplashScreen()
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (state.errorMessage != null) {
            NoticeCard(state.errorMessage, error = true)
        }

        if (game == null) {
            NoticeCard("Waiting for table state...")
            return
        }

        val bottomColor = state.playerColor ?: "white"
        val activeMoves = if (
            game.turn?.color == state.playerColor &&
            game.pendingTurnDecision == null &&
            game.openingRoll?.pending != true
        ) {
            game.legalMoves
        } else {
            emptyList()
        }

        val selectedFrom = remember(game.turn?.number, game.dice?.movesPlayed?.size, game.legalMoves.hashCode()) {
            mutableStateOf<SpaceRef?>(null)
        }
        val targets = selectedFrom.value?.let { source ->
            activeMoves.filter { it.fromSpace() == source }
        } ?: emptyList()

        HeroCard(
            title = catalogs.variantTitle(settings.languageId, game.variant.id),
            body = when {
                game.bot?.enabled == true ->
                    strings.text("game.againstBot", mapOf("color" to colorLabel(strings, bottomColor), "bot" to (game.bot.name ?: strings.text("lobby.computer"))))
                bottomColor.isNotBlank() ->
                    strings.text("game.againstHuman", mapOf("color" to colorLabel(strings, bottomColor)))
                else -> strings.text("game.settingUp")
            },
        )

        if (game.seatReclaim != null) {
            AppCard {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(strings.text("game.seatWarning"), style = MaterialTheme.typography.titleLarge)
                    Text(
                        strings.text(
                            "game.reclaimingSeat",
                            mapOf("name" to (game.seatReclaim.claimantName ?: strings.text("someone"))),
                        ),
                    )
                    Button(onClick = onRemainSeated) {
                        Text(strings.text("game.remainSeated"))
                    }
                }
            }
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(strings.text("game.currentPlayer"), style = MaterialTheme.typography.titleLarge)
                Text(
                    when {
                        game.match.isOver && game.match.winner != null ->
                            strings.text("game.wonBy", mapOf("winner" to colorLabel(strings, game.match.winner), "kind" to (game.match.winnerKind ?: strings.text("unknown"))))
                        game.turn?.playerName != null ->
                            strings.text("game.toMove", mapOf("player" to game.turn.playerName))
                        game.status == "waiting_for_opponent" ->
                            strings.text("game.waitingOpponent")
                        game.openingRoll?.pending == true ->
                            strings.text("game.rollToStart")
                        else -> strings.text("game.settingUp")
                    },
                )
            }
        }

        if (game.openingRoll?.pending == true) {
            OpeningRollCard(strings, bottomColor, game.openingRoll)
        }

        BoardCard(
            strings = strings,
            bottomColor = bottomColor,
            turnColor = game.turn?.color ?: bottomColor,
            board = game.board,
            sourceSpaces = activeMoves.map { it.fromSpace() }.distinct(),
            selectedSource = selectedFrom.value,
            targetSpaces = targets.map { it.toSpace() },
            onSelectSource = { source ->
                selectedFrom.value = source
            },
            onSelectTarget = { target ->
                val move = targets.firstOrNull { it.toSpace() == target }
                if (move != null) {
                    onSpaceSelected(move)
                    selectedFrom.value = null
                }
            },
            dice = game.dice,
            openingRoll = game.openingRoll,
        )

        ActionCard(
            strings = strings,
            canRoll = game.uiActions.canRoll && game.pendingMatchOptions == null && game.pendingTurnDecision == null,
            canUndo = game.uiActions.canUndo,
            canConfirm = game.uiActions.canConfirm,
            canReset = game.uiActions.canReset,
            onRoll = onRoll,
            onUndo = onUndo,
            onConfirm = onConfirm,
            onReset = onReset,
            onResign = onResign,
        )

        if (game.pendingMatchOptions != null) {
            MatchOptionsCard(
                strings = strings,
                payload = game.pendingMatchOptions,
                playerColor = bottomColor,
                onSubmit = onSubmitOptions,
            )
        }

        if (game.pendingTurnDecision != null) {
            TurnDecisionCard(strings, game.pendingTurnDecision, onSubmitDecision)
        }

        MatchSummaryCard(strings, game)

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(strings.text("chat.title"), style = MaterialTheme.typography.titleLarge)
                if (game.chat.isEmpty()) {
                    Text(strings.text("chat.empty"), color = HermesColors.Ink.copy(alpha = 0.7f))
                } else {
                    game.chat.forEach { message ->
                        Text("${message.displayAuthor(state.playerColor)}: ${message.displayText()}")
                    }
                }
                LabeledField(
                    label = strings.text("chat.placeholder"),
                    value = chatDraft,
                    onValueChange = { chatDraft = it },
                )
                Button(
                    onClick = {
                        val text = chatDraft.trim()
                        if (text.isNotEmpty()) {
                            onSendChat(text)
                            chatDraft = ""
                        }
                    },
                ) {
                    Text(strings.text("chat.send"))
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun LocalScreen(
    strings: SharedStrings,
    state: LocalTableState,
    onSpaceSelected: (SpaceRef, SpaceRef?) -> Unit,
    onStartOrRoll: () -> Unit,
    onUndo: () -> Unit,
    onReset: () -> Unit,
) {
    val game = state.game
    val board = state.board

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HeroCard(
            title = "Local Backgammon",
            body = "Offline English backgammon runs from the vendored Kotlin ruleset while the Elixir server remains authoritative online.",
        )

        if (state.errorMessage != null) {
            NoticeCard(state.errorMessage, error = true)
        }

        if (game == null || board == null) {
            SplashScreen()
            return
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Score", style = MaterialTheme.typography.titleLarge)
                Text("White ${game.playerScore1} - Black ${game.playerScore2}")
                Text("Turn: ${colorLabel(strings, board.turnColor)}")
            }
        }

        BoardCard(
            strings = strings,
            bottomColor = board.bottomColor,
            turnColor = board.turnColor,
            board = BoardDto(
                points = board.points.map { PointDto(it.key, it.value) }.sortedBy { it.index },
                bar = board.bar,
                outside = board.outside,
            ),
            sourceSpaces = board.movable,
            selectedSource = state.selectedSource,
            targetSpaces = state.selectedSource?.let { board.targetsBySource[it].orEmpty() }.orEmpty(),
            onSelectSource = { source -> onSpaceSelected(source, null) },
            onSelectTarget = { target ->
                state.selectedSource?.let { source -> onSpaceSelected(source, target) }
            },
            dice = game.dice?.let {
                DiceDto(
                    values = listOf(it.num1, it.num2),
                    movesLeft = game.gameState?.numbersLeft?.toList().orEmpty(),
                )
            },
            openingRoll = null,
        )

        ActionCard(
            strings = strings,
            canRoll = game.dice == null && game.currentRoundResult() == Result.RUNNING,
            canUndo = game.gameState?.let { it.numbersLeft.size < (game.dice?.numbers()?.size ?: 0) } == true,
            canConfirm = false,
            canReset = true,
            onRoll = onStartOrRoll,
            onUndo = onUndo,
            onConfirm = {},
            onReset = onReset,
            onResign = onReset,
        )
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun SettingsScreen(
    strings: SharedStrings,
    catalogs: SharedCatalogs,
    settings: SettingsState,
    onSettingsChange: (SettingsState) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(strings.text("language"), style = MaterialTheme.typography.titleLarge)
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    catalogs.languageOptions.forEach { option ->
                        FilterChip(
                            selected = option.id == settings.languageId,
                            onClick = { onSettingsChange(settings.copy(languageId = option.id)) },
                            label = { Text(option.label) },
                        )
                    }
                }
            }
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(strings.text("game.pack"), style = MaterialTheme.typography.titleLarge)
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    catalogs.soundPacks.packs.forEach { pack ->
                        FilterChip(
                            selected = pack.id == settings.soundPackId,
                            onClick = { onSettingsChange(settings.copy(soundPackId = pack.id)) },
                            label = { Text(pack.label) },
                        )
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(strings.text("game.soundOn"))
                    Switch(
                        checked = settings.soundEnabled,
                        onCheckedChange = { onSettingsChange(settings.copy(soundEnabled = it)) },
                    )
                }
            }
        }

        AppCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LabeledField(
                    label = "Server URL",
                    value = settings.serverUrl,
                    onValueChange = { onSettingsChange(settings.copy(serverUrl = it)) },
                )
                Text(
                    text = "Dormant vendor flows are preserved in code and hard-disabled at runtime: ${BuildConfig.ENABLE_DORMANT_VENDOR_FLOWS}",
                    style = MaterialTheme.typography.bodySmall,
                    color = HermesColors.Ink.copy(alpha = 0.75f),
                )
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun AppCard(content: @Composable Column.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = HermesColors.Card.copy(alpha = 0.9f),
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }
}

@Composable
private fun HeroCard(title: String, body: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Transparent,
        ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        listOf(
                            HermesColors.Wood.copy(alpha = 0.9f),
                            HermesColors.FeltDark.copy(alpha = 0.95f),
                        ),
                    ),
                )
                .border(1.dp, HermesColors.CardBorder)
                .padding(18.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.displayMedium,
                    color = HermesColors.Gold,
                )
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyLarge,
                    color = HermesColors.Ink.copy(alpha = 0.88f),
                )
            }
        }
    }
}

@Composable
private fun NoticeCard(message: String, error: Boolean = false) {
    AppCard {
        Text(
            text = message,
            color = if (error) HermesColors.AccentRed else HermesColors.Ink,
        )
    }
}

@Composable
private fun LabeledField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    enabled: Boolean = true,
) {
    OutlinedTextField(
        modifier = Modifier.fillMaxWidth(),
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        label = { Text(label) },
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
    )
}

@Composable
private fun OpeningRollCard(
    strings: SharedStrings,
    bottomColor: String,
    openingRoll: OpeningRollDto,
) {
    val topColor = oppositeColor(bottomColor)
    AppCard {
        Text(strings.text("game.openingRoll"), style = MaterialTheme.typography.titleLarge)
        Text(strings.text("game.rollToStart"))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            OpeningRollEntry(strings, bottomColor, openingRoll.rolls[bottomColor])
            OpeningRollEntry(strings, topColor, openingRoll.rolls[topColor])
        }
    }
}

@Composable
private fun OpeningRollEntry(strings: SharedStrings, color: String, value: Int?) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(colorLabel(strings, color))
        if (value == null) {
            Text(strings.text("waiting"))
        } else {
            DieImage(color, value)
        }
    }
}

@Composable
private fun ActionCard(
    strings: SharedStrings,
    canRoll: Boolean,
    canUndo: Boolean,
    canConfirm: Boolean,
    canReset: Boolean,
    onRoll: () -> Unit,
    onUndo: () -> Unit,
    onConfirm: () -> Unit,
    onReset: () -> Unit,
    onResign: () -> Unit,
) {
    AppCard {
        Text(strings.text("game.actions"), style = MaterialTheme.typography.titleLarge)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onRoll, enabled = canRoll, modifier = Modifier.weight(1f)) {
                Text(strings.text("game.roll"))
            }
            Button(onClick = onUndo, enabled = canUndo, modifier = Modifier.weight(1f)) {
                Text(strings.text("game.undo"))
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onConfirm, enabled = canConfirm, modifier = Modifier.weight(1f)) {
                Text(strings.text("game.confirm"))
            }
            Button(onClick = onReset, enabled = canReset, modifier = Modifier.weight(1f)) {
                Text(strings.text("game.newMatch"))
            }
        }
        TextButton(onClick = onResign) {
            Text(strings.text("game.resign"))
        }
    }
}

@Composable
private fun MatchOptionsCard(
    strings: SharedStrings,
    payload: MatchOptionsDto,
    playerColor: String,
    onSubmit: (Map<String, Any>) -> Unit,
) {
    val draft = remember(payload.kind) { mutableStateMapOf<String, Any>() }

    AppCard {
        Text(strings.text("game.matchOptions"), style = MaterialTheme.typography.titleLarge)
        Text(payload.prompt ?: strings.text("game.choosePregame"))

        if (payload.options.isNotEmpty()) {
            payload.options.forEach { option ->
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(option.label ?: option.prompt ?: option.key)
                    if (option.choices.isNotEmpty()) {
                        Row(
                            modifier = Modifier.horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            option.choices.forEach { choice ->
                                FilterChip(
                                    selected = draft[option.key]?.toString() == choice.value,
                                    onClick = { draft[option.key] = choice.value },
                                    label = { Text(choice.label ?: choice.value) },
                                )
                            }
                        }
                    } else {
                        val defaultValue = option.defaultValue
                        if (defaultValue?.isJsonPrimitive == true && defaultValue.asJsonPrimitive.isBoolean) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(option.key)
                                Checkbox(
                                    checked = draft[option.key] as? Boolean ?: defaultValue.asBoolean,
                                    onCheckedChange = { draft[option.key] = it },
                                )
                            }
                        } else {
                            LabeledField(
                                label = option.key,
                                value = draft[option.key]?.toString() ?: defaultValue?.asString.orEmpty(),
                                onValueChange = { draft[option.key] = it },
                            )
                        }
                    }
                }
            }
            Button(onClick = { onSubmit(draft.toMap()) }) {
                Text(strings.text("game.startMatch"))
            }
        } else {
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                payload.choices.forEach { choice ->
                    FilterChip(
                        selected = false,
                        onClick = {
                            val key = when (payload.kind) {
                                "trictrac_partie_length_consent" -> "aEcrirePartieLengthConsent"
                                "tavli_target_consent" -> "tavliTarget"
                                else -> "margotConsent"
                            }
                            onSubmit(mapOf(key to choice))
                        },
                        label = {
                            Text(
                                payload.choiceLabels[choice]
                                    ?: if (choice == "yes" || choice == "no") strings.text(choice) else choice,
                            )
                        },
                    )
                }
            }
            if (payload.responses.isNotEmpty()) {
                Divider(color = HermesColors.CardBorder)
                Text("${strings.text("game.yourChoice")}: ${payload.responses[playerColor] ?: strings.text("waiting")}")
            }
        }
    }
}

@Composable
private fun TurnDecisionCard(
    strings: SharedStrings,
    payload: TurnDecisionDto,
    onSubmit: (String) -> Unit,
) {
    AppCard {
        Text(strings.text("game.decision"), style = MaterialTheme.typography.titleLarge)
        Text(payload.prompt ?: payload.key.orEmpty())
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            payload.choices.forEach { choice ->
                FilterChip(
                    selected = false,
                    onClick = { onSubmit(choice) },
                    label = { Text(choice) },
                )
            }
        }
    }
}

@Composable
private fun MatchSummaryCard(strings: SharedStrings, game: GameSnapshotDto) {
    AppCard {
        Text(strings.text("game.match"), style = MaterialTheme.typography.titleLarge)
        Text("White ${game.match.score["white"] ?: 0} - Black ${game.match.score["black"] ?: 0}")
        if (game.match.winner != null) {
            Text(strings.text("game.wonBy", mapOf("winner" to colorLabel(strings, game.match.winner), "kind" to (game.match.winnerKind ?: strings.text("unknown")))))
        }
    }
}

@Composable
private fun BoardCard(
    strings: SharedStrings,
    bottomColor: String,
    turnColor: String,
    board: BoardDto,
    sourceSpaces: List<SpaceRef>,
    selectedSource: SpaceRef?,
    targetSpaces: List<SpaceRef>,
    onSelectSource: (SpaceRef) -> Unit,
    onSelectTarget: (SpaceRef) -> Unit,
    dice: DiceDto?,
    openingRoll: OpeningRollDto?,
) {
    val topColor = oppositeColor(bottomColor)
    val layout = if (bottomColor == "white") {
        (23 downTo 12).toList() to (0..11).toList()
    } else {
        (0..11).toList() to (23 downTo 12).toList()
    }
    val pointMap = remember(board.points) { board.points.associateBy { it.index } }
    val boardBackground = rememberAssetBitmap("images/6besh/board-wood.jpg")

    AppCard {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .requiredHeight(420.dp)
                .clip(MaterialTheme.shapes.large),
        ) {
            if (boardBackground != null) {
                Image(
                    bitmap = boardBackground,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(10.dp),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                BoardRow(
                    pointIndexes = layout.first,
                    pointMap = pointMap,
                    isTop = true,
                    sourceSpaces = sourceSpaces,
                    selectedSource = selectedSource,
                    targetSpaces = targetSpaces,
                    onSelectSource = onSelectSource,
                    onSelectTarget = onSelectTarget,
                )
                MiddleRail(
                    strings = strings,
                    board = board,
                    topColor = topColor,
                    bottomColor = bottomColor,
                    turnColor = turnColor,
                    sourceSpaces = sourceSpaces,
                    selectedSource = selectedSource,
                    targetSpaces = targetSpaces,
                    onSelectSource = onSelectSource,
                    onSelectTarget = onSelectTarget,
                    dice = if (openingRoll?.pending == true) null else dice,
                )
                BoardRow(
                    pointIndexes = layout.second,
                    pointMap = pointMap,
                    isTop = false,
                    sourceSpaces = sourceSpaces,
                    selectedSource = selectedSource,
                    targetSpaces = targetSpaces,
                    onSelectSource = onSelectSource,
                    onSelectTarget = onSelectTarget,
                )
            }
        }
    }
}

@Composable
private fun BoardRow(
    pointIndexes: List<Int>,
    pointMap: Map<Int, PointDto>,
    isTop: Boolean,
    sourceSpaces: List<SpaceRef>,
    selectedSource: SpaceRef?,
    targetSpaces: List<SpaceRef>,
    onSelectSource: (SpaceRef) -> Unit,
    onSelectTarget: (SpaceRef) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        pointIndexes.chunked(6).forEachIndexed { chunkIndex, chunk ->
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                chunk.forEach { index ->
                    val point = pointMap[index] ?: PointDto(index)
                    val space = SpaceRef.Point(index)
                    val isSource = space in sourceSpaces
                    val isTarget = space in targetSpaces
                    PointTriangle(
                        point = point,
                        isTop = isTop,
                        isSource = isSource,
                        isTarget = isTarget,
                        isSelected = selectedSource == space,
                        onClick = {
                            when {
                                isTarget -> onSelectTarget(space)
                                isSource -> onSelectSource(space)
                            }
                        },
                    )
                }
            }
            if (chunkIndex == 0) {
                Spacer(Modifier.width(10.dp))
            }
        }
    }
}

@Composable
private fun MiddleRail(
    strings: SharedStrings,
    board: BoardDto,
    topColor: String,
    bottomColor: String,
    turnColor: String,
    sourceSpaces: List<SpaceRef>,
    selectedSource: SpaceRef?,
    targetSpaces: List<SpaceRef>,
    onSelectSource: (SpaceRef) -> Unit,
    onSelectTarget: (SpaceRef) -> Unit,
    dice: DiceDto?,
) {
    val activeBarIsBottom = turnColor == bottomColor
    val barSource = SpaceRef.Bar in sourceSpaces
    val homeTarget = SpaceRef.Home in targetSpaces

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(92.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Pocket(
            label = strings.text("game.opponentBar"),
            count = board.bar[topColor] ?: 0,
            color = topColor,
            actionable = barSource && !activeBarIsBottom,
            selected = selectedSource == SpaceRef.Bar && !activeBarIsBottom,
            onClick = {
                if (barSource && !activeBarIsBottom) onSelectSource(SpaceRef.Bar)
            },
        )
        DiceStrip(dice = dice, color = turnColor)
        Pocket(
            label = strings.text("game.bearOff"),
            count = board.outside[turnColor] ?: 0,
            color = turnColor,
            actionable = homeTarget,
            selected = false,
            onClick = { if (homeTarget) onSelectTarget(SpaceRef.Home) },
        )
        Pocket(
            label = strings.text("game.yourBar"),
            count = board.bar[bottomColor] ?: 0,
            color = bottomColor,
            actionable = barSource && activeBarIsBottom,
            selected = selectedSource == SpaceRef.Bar && activeBarIsBottom,
            onClick = {
                if (barSource && activeBarIsBottom) onSelectSource(SpaceRef.Bar)
            },
        )
    }
}

@Composable
private fun Pocket(
    label: String,
    count: Int,
    color: String,
    actionable: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val background = when {
        selected -> HermesColors.AccentGreen.copy(alpha = 0.75f)
        actionable -> HermesColors.Gold.copy(alpha = 0.72f)
        else -> Color(0x66220C08)
    }

    Column(
        modifier = Modifier
            .width(72.dp)
            .clip(MaterialTheme.shapes.medium)
            .background(background)
            .clickable(enabled = actionable, onClick = onClick)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            label,
            color = HermesColors.Ink,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodySmall,
        )
        CheckerChip(color)
        Text(count.toString(), style = MaterialTheme.typography.labelMedium, color = HermesColors.Ink)
    }
}

@Composable
private fun PointTriangle(
    point: PointDto,
    isTop: Boolean,
    isSource: Boolean,
    isTarget: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val triangleShape = remember(isTop) {
        GenericShape { size, _ ->
            if (isTop) {
                moveTo(0f, 0f)
                lineTo(size.width, 0f)
                lineTo(size.width / 2f, size.height)
            } else {
                moveTo(size.width / 2f, 0f)
                lineTo(0f, size.height)
                lineTo(size.width, size.height)
            }
            close()
        }
    }
    val fill = when {
        isSelected -> HermesColors.AccentGreen
        isTarget -> HermesColors.Gold
        point.index % 2 == 0 -> HermesColors.FeltDark
        else -> HermesColors.FeltLight
    }

    Box(
        modifier = Modifier
            .weight(1f)
            .height(150.dp)
            .clip(triangleShape)
            .background(fill)
            .border(1.dp, HermesColors.CardBorder, triangleShape)
            .clickable(enabled = isSource || isTarget, onClick = onClick),
    ) {
        Text(
            text = (point.index + 1).toString(),
            modifier = Modifier
                .align(if (isTop) Alignment.TopCenter else Alignment.BottomCenter)
                .padding(6.dp),
            style = MaterialTheme.typography.labelMedium,
            color = HermesColors.Ink,
        )
        CheckerStack(
            modifier = Modifier
                .align(if (isTop) Alignment.BottomCenter else Alignment.TopCenter)
                .padding(vertical = 8.dp),
            pieces = point.pieces,
            stackDown = isTop,
        )
    }
}

@Composable
private fun CheckerStack(
    modifier: Modifier = Modifier,
    pieces: List<String>,
    stackDown: Boolean,
) {
    Box(modifier = modifier.width(32.dp).height(100.dp)) {
        pieces.take(5).forEachIndexed { index, color ->
            CheckerChip(
                color = color,
                modifier = Modifier
                    .align(if (stackDown) Alignment.TopCenter else Alignment.BottomCenter)
                    .padding(top = if (stackDown) (index * 14).dp else 0.dp, bottom = if (stackDown) 0.dp else (index * 14).dp),
            )
        }
        if (pieces.size > 5) {
            Text(
                text = pieces.size.toString(),
                modifier = Modifier.align(Alignment.Center),
                color = HermesColors.Ink,
                style = MaterialTheme.typography.labelMedium,
            )
        }
    }
}

@Composable
private fun CheckerChip(color: String, modifier: Modifier = Modifier) {
    val asset = when (color) {
        "white", "green" -> "images/6besh/checker-green.png"
        else -> "images/6besh/checker-red.png"
    }
    val bitmap = rememberAssetBitmap(asset)

    if (bitmap != null) {
        Image(
            bitmap = bitmap,
            contentDescription = null,
            modifier = modifier.size(28.dp),
        )
    } else {
        Box(
            modifier = modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(if (color == "white" || color == "green") HermesColors.AccentGreen else HermesColors.AccentRed),
        )
    }
}

@Composable
private fun DiceStrip(dice: DiceDto?, color: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        (dice?.values ?: emptyList()).forEach { value ->
            DieImage(color, value)
        }
    }
}

@Composable
private fun DieImage(color: String, value: Int) {
    val asset = when (color) {
        "white", "green" -> "images/6besh/dice_green$value.png"
        else -> "images/6besh/dice_red$value.png"
    }
    val bitmap = rememberAssetBitmap(asset)
    if (bitmap != null) {
        Image(
            bitmap = bitmap,
            contentDescription = "Die $value",
            modifier = Modifier.size(34.dp),
        )
    } else {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(MaterialTheme.shapes.small)
                .background(HermesColors.Gold),
            contentAlignment = Alignment.Center,
        ) {
            Text(value.toString(), color = HermesColors.Walnut)
        }
    }
}

@Composable
private fun rememberAssetBitmap(path: String): ImageBitmap? {
    val context = LocalContext.current
    return remember(path) {
        runCatching {
            context.assets.open(path).use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
        }.getOrNull()
    }
}

private fun oppositeColor(color: String): String = if (color == "white") "black" else "white"

private fun colorLabel(strings: SharedStrings, color: String): String = strings.text("color.$color", fallback = color.replaceFirstChar { it.uppercase() })

private fun JsonElement.asJsonObjectOrNull(): JsonObject? =
    if (isJsonObject) asJsonObject else null

private fun Map<String, Any>.toJsonObject(): JsonObject = JsonObject().apply {
    forEach { (key, value) ->
        when (value) {
            is Boolean -> addProperty(key, value)
            is Number -> addProperty(key, value)
            else -> addProperty(key, value.toString())
        }
    }
}

private fun Context.assetsReadText(path: String): String = assets.open(path).bufferedReader().use { it.readText() }

private fun android.content.res.AssetManager.readText(path: String): String =
    open(path).bufferedReader().use { it.readText() }
