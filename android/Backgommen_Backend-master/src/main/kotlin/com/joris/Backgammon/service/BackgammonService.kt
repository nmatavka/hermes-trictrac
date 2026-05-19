package com.joris.Backgammon.service

import com.joris.Backgammon.CustomExceptions.UserNotFoundException
import com.joris.Backgammon.dto.*
import com.joris.Backgammon.dto.User
import com.mongodb.MongoException
import com.mongodb.kotlin.client.coroutine.MongoClient
import com.mongodb.client.model.Filters
import com.mongodb.client.model.Updates
import kotlinx.coroutines.flow.firstOrNull
import org.bson.types.ObjectId
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import kotlin.random.Random
import java.time.Instant

@Service
class BackgammonService (
    @Value("\${mongo.host}")
     val mongoHost: String,

    @Value("\${mongo.port}")
    val mongoPort: String,

    @Value("\${mongo.name}")
    val mongoName: String,

    @Value("\${mongo.games}")
    val gameCollection : String,

    @Value("\${mongo.users}")
    val usersCollections : String


) {

    private val dbClient = MongoClient.create("mongodb://$mongoHost:$mongoPort").getDatabase(mongoName)
    private val logger = LoggerFactory.getLogger(this::class.java)


    suspend fun registerNewGame(userId : String, userPlays : Side, difficulty : DifficultyLevel) : String? {

        val newGame = BackgammonGame(
            gameID = ObjectId(),
            userID = userId,
            userPlays = userPlays,
            currStateOfTransaction = PossibleGameStates.NOT_STARTED,
            createdAt = Instant.now(),
            modelDifficulty = difficulty
        )
        val gameIDCreated : String? = try {
            val col = dbClient.getCollection<BackgammonGame>(gameCollection)
            val result = col.insertOne(newGame)
            val insertedId = result.insertedId?.asObjectId()?.value
            logger.info("Created game with ID: ${insertedId}")
            insertedId.toString();
        } catch (e : MongoException){
            logger.error("Error occured when trying to create the game for user with ID : ${userId}!")
            null
        }
        return gameIDCreated;
    }

    suspend fun startGame(gameId : String) : Unit {
        val col = dbClient.getCollection<BackgammonGame>(gameCollection)
        val filter = Filters.eq(BackgammonGame::gameID.name, gameId);
        val update = Updates.combine(
            Updates.set(BackgammonGame::currStateOfTransaction.name, PossibleGameStates.ONGOING),
            Updates.currentTimestamp(BackgammonGame::startedAt.name)
        )
        val result = col.findOneAndUpdate(filter, update)
        if (result == null) {
            logger.error("Game with ID: ${gameId} not found")
        }

    }

    suspend fun abortOngoingGame(){

    }

    suspend fun playMove(){

    }

    private fun getStartingPlayer() : Player {
        return if(Random.nextInt(0, 10) >= 5) {
            return Player.CPU
        } else {
            return Player.USER
        }
    }


}