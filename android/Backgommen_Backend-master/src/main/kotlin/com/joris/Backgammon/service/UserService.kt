package com.joris.Backgammon.service
import com.joris.Backgammon.dto.Sessions
import com.joris.Backgammon.dto.User
import com.mongodb.MongoException
import com.mongodb.client.model.Filters
import com.mongodb.kotlin.client.coroutine.MongoDatabase
import kotlinx.coroutines.flow.firstOrNull
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Duration
import java.time.Instant
import java.util.*

@Service
class UserService (
    private val database : MongoDatabase,
    @Value("\${mongo.users}")
    val usersCollections : String,

    @Value("\${mongo.sessions}")
    val sessionsCollection : String
)
{

    private val logger = LoggerFactory.getLogger(this::class.java);
    private val md = MessageDigest.getInstance("SHA-256");

    suspend fun registerUser(user : User) : String?{
        try{
            val userCol =  database.getCollection<User>(usersCollections);
            user.password = hashPassword(user.password)
            val res = userCol.insertOne(user);
            logger.info("user created with id: ${res.insertedId.toString()}")
            return user.userName;
        }catch( e : MongoException){
            logger.error("Could not register user!")
            return null
        }
    }

    private fun hashPassword(password: String): String {
        val salt = generateSalt()
        this.md.update(salt)
        val hashedBytes = md.digest(password.toByteArray())
        return Base64.getEncoder().encodeToString(hashedBytes)
    }

    private fun generateSalt(): ByteArray {
        val salt = ByteArray(16) // 128-bit salt
        SecureRandom().nextBytes(salt)
        return salt
    }

    private fun generateSession() : String{
        val uuid = UUID.randomUUID()
        return uuid.toString()
    }


    suspend fun checkUserExists( email : String) : Boolean{
        logger.info("start checking if user : ${email} exists")
        val userCol = database.getCollection<User>(usersCollections);
        val filter = Filters.or(
            Filters.eq(User::email.name, email)
        )
        val res = userCol.find(filter);
        val found = res.firstOrNull() != null
        logger.info("result : ${found}")
        return found;
    }

    suspend fun loginUser(email : String, password : String) : String? {
        val userCol = database.getCollection<User>(usersCollections);
        val passwordHash = hashPassword(password);
        logger.info(passwordHash)
        val filters = Filters.and(
            Filters.eq(User::email.name, email),
            Filters.eq(User::password.name, passwordHash)
        )

        val userFound = userCol.find(filters).firstOrNull()
        logger.info(userFound.toString())
        if (userFound is User){
            val sessionId =  generateSession();
            val sessCol = database.getCollection<Sessions>(sessionsCollection);
            val newSession = Sessions(
                userId = userFound.userId!!,
                sessionId = sessionId,
                createdAt = Date.from(Instant.now()),
                expiresAt = Date.from(Instant.now().plus(Duration.ofHours(3)))
            )
            sessCol.insertOne(newSession)
            return sessionId;
        }else{
            return null;
        }

    }

    //suspend fun logoutUser(): Unit{

    //}



}