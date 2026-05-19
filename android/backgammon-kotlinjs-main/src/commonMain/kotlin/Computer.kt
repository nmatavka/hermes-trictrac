import org.w3c.dom.*
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.Serializable

/**
 * Query data from Computer to AI Worker.
 */
@Serializable
class QueryData(
    val gameState: GameState,
    val level: Int,
    val timeLimitMs: Int
)

/**
 * Response data from AI Worker, which contains the moves made by the computer.
 */
@Serializable
class ResponseData(
    val moves: List<Move>
)

/**
 * Represents an AI player that receives queries, and sends back the moves chosen asynchronously.
 */
class Computer (level: Int, val callback: (List<Move>) -> Unit, val timeLimitMs: Int =  500) {
    val level: Int = run {
        if (level !in 1..5) throw IllegalArgumentException("Invalid computer level: $level")
        level
    }


    private val worker: Worker = Worker("worker.js", WorkerOptions(WorkerType.MODULE))

    init {
        worker.onmessage = {processWorkerResult(it)}
    }

    fun query(gameState: GameState) {
        val data = QueryData(gameState, level, timeLimitMs)
        worker.postMessage(Json.encodeToString(data))
    }

    private fun processWorkerResult(messageEvent: MessageEvent) {
        val data: ResponseData = Json.decodeFromString(messageEvent.data as String)
        callback(data.moves)
    }

}
