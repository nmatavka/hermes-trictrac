package com.example.backgammon

import com.google.firebase.firestore.FirebaseFirestore
import android.util.Log

data class PlayerScore(
    val playerName: String = "",
    val wins: Int = 0,
    val losses: Int = 0,
    val trophies: Int = 0
)

class ScoreManager {
    companion object {
        private const val TAG = "ScoreManager"
        private const val COLLECTION_SCORES = "player_scores"
    }
    
    private val db = FirebaseFirestore.getInstance()
    
    fun getPlayerScore(playerName: String, callback: (PlayerScore?) -> Unit) {
        db.collection(COLLECTION_SCORES)
            .document(playerName)
            .get()
            .addOnSuccessListener { document ->
                if (document.exists()) {
                    val score = document.toObject(PlayerScore::class.java)
                    callback(score)
                } else {
                    // שחקן חדש - ניצור רשומה ראשונה
                    val newScore = PlayerScore(playerName = playerName)
                    callback(newScore)
                }
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Error getting player score", exception)
                callback(null)
            }
    }
    
    fun recordWin(playerName: String, callback: (PlayerScore?) -> Unit) {
        getPlayerScore(playerName) { currentScore ->
            if (currentScore != null) {
                val updatedScore = currentScore.copy(
                    wins = currentScore.wins + 1,
                    trophies = currentScore.trophies + 1
                )
                savePlayerScore(updatedScore, callback)
            } else {
                callback(null)
            }
        }
    }
    
    fun recordLoss(playerName: String, callback: (PlayerScore?) -> Unit) {
        getPlayerScore(playerName) { currentScore ->
            if (currentScore != null) {
                val updatedScore = currentScore.copy(
                    losses = currentScore.losses + 1,
                    trophies = currentScore.trophies - 1
                )
                savePlayerScore(updatedScore, callback)
            } else {
                callback(null)
            }
        }
    }
    
    private fun savePlayerScore(score: PlayerScore, callback: (PlayerScore?) -> Unit) {
        db.collection(COLLECTION_SCORES)
            .document(score.playerName)
            .set(score)
            .addOnSuccessListener {
                Log.d(TAG, "Score updated successfully for ${score.playerName}")
                callback(score)
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Error updating score", exception)
                callback(null)
            }
    }
} 