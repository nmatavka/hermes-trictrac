import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import org.w3c.dom.DedicatedWorkerGlobalScope
import org.w3c.dom.MessageEvent
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import scorers.Dumbeval
import scorers.Pubeval
import scorers.Scorer
import scorers.TDGammon

external val self: DedicatedWorkerGlobalScope

// global scorer, used by nodes in the minimax tree to evaluate states
var scorer: Scorer = Pubeval(50f)
var currentLevel = -2

val maxDepthPerLevel = mapOf(1 to 2, 2 to 2, 3 to 3, 4 to 3, 5 to 3)

suspend fun initializeScorer(level: Int) {
    if (level == 1) {
        scorer = Dumbeval()
    } else if (level <= 3) {
        scorer = Pubeval(50f)
    } else {
        val td = TDGammon("bkgm_net.onnx")
        td.initialize()
        scorer = td
    }
}


fun makeSuggestion(messageEvent: MessageEvent) {
    console.log("Worker got query")
    val query: QueryData = Json.decodeFromString(messageEvent.data as String)

    // launch the tree search in a coroutine, as the TDGammon scorer runs asynchronously
    // and needs to be in a suspend function
    GlobalScope.launch(Dispatchers.Unconfined) {
        if (currentLevel != query.level) {
            initializeScorer(query.level)
            currentLevel = query.level
        }
        val maxDepth = maxDepthPerLevel[query.level]!!

        val score = scorer.score(query.gameState, query.gameState.turnOf)
        console.log("Computer's score: $score")

        val root = MiniMaxNode(true)
        val action = iterativeDeepeningSearch(root, query.gameState, query.timeLimitMs, maxDepth = maxDepth)

        val response = ResponseData(action)
        self.postMessage(Json.encodeToString(response))
        console.log("Worker sent response: $action")
    }
}

fun main() {
    self.onmessage = ::makeSuggestion
}