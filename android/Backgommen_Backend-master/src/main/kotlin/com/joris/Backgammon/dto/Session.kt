package com.joris.Backgammon.dto
import java.util.Date
import org.bson.codecs.pojo.annotations.BsonId
import org.bson.types.ObjectId

data class Sessions(
    @BsonId
    val userId : ObjectId,
    val sessionId : String,
    val createdAt : Date,
    val expiresAt : Date
)