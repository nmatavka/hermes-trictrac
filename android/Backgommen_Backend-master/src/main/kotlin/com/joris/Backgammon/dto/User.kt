package com.joris.Backgammon.dto

import org.bson.codecs.pojo.annotations.BsonId
import org.bson.codecs.pojo.annotations.BsonProperty
import org.bson.types.ObjectId


data class User(
    @BsonId val userId: ObjectId? = null,
    val email: String,
    val name: String,
    val userName: String,
    var password: String
)
enum class Themes {
    WHITE, BLACK
}

data class userSettings (
    val defaultDifficulty : DifficultyLevel,
    val defaultTheme : Themes
)

