package com.joris.Backgammon.service

import com.mongodb.kotlin.client.coroutine.MongoClient
import com.mongodb.kotlin.client.coroutine.MongoDatabase
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration


@Configuration
class MongoConfig {

    @Value("\${mongo.host}")
    lateinit var mongoHost: String

    @Value("\${mongo.port}")
    lateinit var mongoPort: String


    @Value("\${mongo.name}")
    lateinit var mongoName: String

    @Bean
    fun mongoClient(): MongoDatabase {
        val m=  MongoClient.create("mongodb://$mongoHost:$mongoPort")
        return m.getDatabase(mongoName)
    }
}