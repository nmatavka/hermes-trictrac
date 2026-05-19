package com.joris.Backgammon.service


import com.joris.Backgammon.dto.Sessions
import com.mongodb.client.model.Indexes
import com.mongodb.kotlin.client.coroutine.MongoClient
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.flow.toSet
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.stereotype.Service
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.awaitExchange

val REQUIREDCOLLECTIONS = setOf("users", "games", "sessions")

@Service
class SetupService(
    @Value("\${mongo.host}") val mongoHost : String,
    @Value("\${mongo.port}") val  mongoPort : String,
    @Value("\${mongo.name}") val  dbName : String,
    @Value("\${backgammon.service.host}")  val backgammonServiceHost : String,
    @Value("\${backgammon.service.port}")  val backgammonServicePort : String

)
{
    private val logger = LoggerFactory.getLogger(this::class.java)

    @EventListener(ApplicationReadyEvent::class)
    suspend fun initApplication(){
        logger.info("start init the app!")
        initDatabase()
        checkBackgammonService()
    }

    suspend fun checkBackgammonService(){
        logger.info("starting the health check for the backgammon backend")
        val client = WebClient.create("http://${backgammonServiceHost}:${backgammonServicePort}");
        client.get()
            .uri("/health")
            .accept(MediaType.APPLICATION_JSON)
            .awaitExchange { response ->
                if (response.statusCode() != HttpStatus.OK){
                    throw Exception("Backgammon Service not reachable")
                }else{
                    logger.info("Health sing from backgammon backend")
                }
            }

    }

    suspend fun initDatabase(){
        logger.info("start initializing mongoDB")
        val mongoClient = MongoClient.create("mongodb://${this.mongoHost}:${this.mongoPort}")
        val db = mongoClient.getDatabase(dbName)
        val collectionNames: Flow<String> = db.listCollectionNames()
        val collectionsList = collectionNames.toSet()
        logger.info("Found collections in the db : ${collectionsList}")
        if (collectionsList == REQUIREDCOLLECTIONS) {
            logger.info("All collections already available")
        }
        else {
                val remainingCollections = REQUIREDCOLLECTIONS - collectionsList
            for (col in remainingCollections){
                db.createCollection(col)
                logger.info("collection: ${col} created")
            }
        }
        mongoClient.close()
        logger.info("setup client closed")
    }

}