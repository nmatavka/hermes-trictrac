package com.joris.Backgammon.dto

import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId
import java.time.Instant


// general

data class BackgammonState(
    val board  : List<Int>,
    val whiteOutside : Int,
    val blackOutside : Int,
    val whiteBearing : Boolean,
    val blackBearing : Boolean,
    val ended : Boolean,
    val caughtBlack : Int,
    val caughtWhite : Int
)

// For the Backgammon Service

data class BackgammonServiceRequest(
    val isBlack : Boolean,
    val curr : BackgammonState
)

data class BackGammonServiceResponse(
    val curr : BackgammonState,
    val next_state : BackgammonState,

)

// For the Database

enum class PossibleGameStates{
    ONGOING, ABORTED_BY_USER, ABORTED_BY_SYSTEM, FINISHED, NOT_STARTED
}

enum class Player {
    USER, CPU
}

enum class Side {
    WHITE, BlACK
}

data class GameMove(
    val player: Player,
    val afterState : BackgammonState,
    val predictionId : String
)

enum class DifficultyLevel{
    EASY, MEDIUM, HARD
}


data class BackgammonGame(
    @BsonId
    val gameID : ObjectId? = null,
    val userPlays : Side,
    val started : Player? = null,
    val userID : String,
    val modelDifficulty: DifficultyLevel,
    val startedAt : String? = null,
    val finishedAt : String? = null,
    val createdAt : Instant,
    val currStateOfTransaction : PossibleGameStates,
    val gameHistory : List<GameMove>? = null
)

// User and Backgammon
data class ongoingGame(
    val isBlack : Boolean,
    @BsonId
    val gameID : Int,

)