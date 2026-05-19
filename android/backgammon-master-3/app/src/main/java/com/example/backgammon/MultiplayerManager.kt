package com.example.backgammon

import android.util.Log
import com.google.firebase.database.*

object MultiplayerManager {
    private val db = FirebaseDatabase.getInstance().reference
    var gameId: String? = null

    fun createGame(playerId: String, onCreated: (String) -> Unit) {
        try {
            Log.d("Backgammon", "Attempting to create a new game")
            val newGameRef = db.child("games").push()
            val data = mapOf(
                "playerWhite" to playerId,
                "playerBlack" to "",
                "currentTurn" to "white",
                "dice1" to 0,
                "dice2" to 0,
                "boardState" to emptyList<List<Any>>()
            )
            newGameRef.setValue(data)
                .addOnSuccessListener {
                    gameId = newGameRef.key
                    Log.d("Backgammon", "Game created successfully with ID: $gameId")
                    gameId?.let { id -> onCreated(id) }
                }
                .addOnFailureListener { exception ->
                    Log.e("Backgammon", "Failed to create game: ${exception.message}", exception)
                    throw exception
                }
        } catch (e: Exception) {
            Log.e("Backgammon", "Exception creating game: ${e.message}", e)
            throw e
        }
    }

    fun joinGame(playerId: String, gameId: String, onJoined: () -> Unit) {
        try {
            Log.d("Backgammon", "Attempting to join game: $gameId")
            this.gameId = gameId
            db.child("games").child(gameId).child("playerBlack")
                .setValue(playerId)
                .addOnSuccessListener {
                    Log.d("Backgammon", "Successfully joined game: $gameId")
                    onJoined()
                }
                .addOnFailureListener { exception ->
                    Log.e("Backgammon", "Failed to join game: ${exception.message}", exception)
                    throw exception
                }
        } catch (e: Exception) {
            Log.e("Backgammon", "Exception joining game: ${e.message}", e)
            throw e
        }
    }

    fun updateGameState(state: Map<String, Any>) {
        gameId?.let {
            db.child("games").child(it).updateChildren(state)
        }
    }

    fun listenToGameState(onUpdate: (DataSnapshot) -> Unit) {
        gameId?.let {
            db.child("games").child(it)
                .addValueEventListener(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        onUpdate(snapshot)
                    }

                    override fun onCancelled(error: DatabaseError) {}
                })
        }
    }
} 