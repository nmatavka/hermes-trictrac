package com.example.backgammon

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.util.UUID

class MainActivity : AppCompatActivity() {
    private lateinit var backgammonBoardView: BackgammonBoardView
    private var playerId = UUID.randomUUID().toString().substring(0, 8)
    private lateinit var gameIdTextView: TextView
    private lateinit var playerInfoTextView: TextView
    private lateinit var userManager: UserManager
    private lateinit var scoreManager: ScoreManager
    private var currentPlayerName: String = ""
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        userManager = UserManager(this)
        scoreManager = ScoreManager()
        
        // בדיקה אם המשתמש מחובר
        if (!userManager.isLoggedIn()) {
            goToLoginActivity()
            return
        }
        
        currentPlayerName = userManager.getPlayerName() ?: ""
        if (currentPlayerName.isEmpty()) {
            goToLoginActivity()
            return
        }
        
        // מניעת הורדת מסך ההתראות
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            insets
        }
        
        // אתחול לוח המשחק
        backgammonBoardView = findViewById(R.id.backgammonBoard)
        gameIdTextView = findViewById(R.id.gameIdTextView)
        playerInfoTextView = findViewById(R.id.playerInfoTextView)
        
        // הגדרת השחקן הנוכחי כתמיד לבן (מתחיל)
        backgammonBoardView.setCurrentPlayerName(currentPlayerName)
        
        setupPlayerInfo()
        
        // חיבור כפתור BACK
        val backButton = findViewById<ImageButton>(R.id.backButton)
        backButton.setOnClickListener {
            backgammonBoardView.undoLastMove()
        }
        
        // חיבור כפתור DONE
        val doneButton = findViewById<ImageButton>(R.id.doneButton)
        doneButton.setOnClickListener {
            backgammonBoardView.finishTurn()
        }
        
        // חיבור כפתור יציאה
        val logoutButton = findViewById<Button>(R.id.logoutButton)
        logoutButton.setOnClickListener {
            logout()
        }
        
        // כפתור לסיום משחק ועדכון ניקוד
        val gameWonButton = findViewById<Button>(R.id.gameWonButton)
        val gameLostButton = findViewById<Button>(R.id.gameLostButton)
        
        gameWonButton.setOnClickListener {
            recordGameResult(true)
        }
        
        gameLostButton.setOnClickListener {
            recordGameResult(false)
        }
        
        // הוספת כפתורים למשחק מקוון
        // setupMultiplayerButtons()
        
        // האזנה לשינויים ב-Firebase
        /*
        MultiplayerManager.listenToGameState { snapshot ->
            backgammonBoardView.syncWithFirebase(snapshot)
        }
        */
    }
    
    private fun setupPlayerInfo() {
        scoreManager.getPlayerScore(currentPlayerName) { playerScore ->
            runOnUiThread {
                if (playerScore != null) {
                    val infoText = "$currentPlayerName (לבן)\nגביעים: ${playerScore.trophies} | נצחונות: ${playerScore.wins} | הפסדים: ${playerScore.losses}"
                    playerInfoTextView.text = infoText
                    playerInfoTextView.visibility = View.VISIBLE
                }
            }
        }
    }
    
    private fun recordGameResult(won: Boolean) {
        val message = if (won) "רשמת ניצחון!" else "רשמת הפסד"
        
        if (won) {
            scoreManager.recordWin(currentPlayerName) { updatedScore ->
                runOnUiThread {
                    if (updatedScore != null) {
                        Toast.makeText(this, "$message +1 גביע", Toast.LENGTH_SHORT).show()
                        setupPlayerInfo() // עדכון התצוגה
                    }
                }
            }
        } else {
            scoreManager.recordLoss(currentPlayerName) { updatedScore ->
                runOnUiThread {
                    if (updatedScore != null) {
                        Toast.makeText(this, "$message -1 גביע", Toast.LENGTH_SHORT).show()
                        setupPlayerInfo() // עדכון התצוגה
                    }
                }
            }
        }
    }
    
    private fun logout() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("יציאה")
        builder.setMessage("האם את בטוחה שאת רוצה לצאת?")
        
        builder.setPositiveButton("כן") { _, _ ->
            userManager.logout()
            goToLoginActivity()
        }
        
        builder.setNegativeButton("ביטול") { dialog, _ ->
            dialog.dismiss()
        }
        
        builder.show()
    }
    
    private fun goToLoginActivity() {
        val intent = Intent(this, LoginActivity::class.java)
        startActivity(intent)
        finish()
    }
    
    private fun setupMultiplayerButtons() {
        val createGameButton = findViewById<Button>(R.id.createGameButton)
        val joinGameButton = findViewById<Button>(R.id.joinGameButton)
        
        createGameButton.setOnClickListener {
            createGame()
        }
        
        joinGameButton.setOnClickListener {
            showJoinGameDialog()
        }
    }
    
    private fun createGame() {
        try {
            Toast.makeText(this, "יוצר משחק חדש...", Toast.LENGTH_SHORT).show()
            MultiplayerManager.createGame(playerId) { gameId ->
                Log.d("Backgammon", "Game created: $gameId")
                runOnUiThread {
                    gameIdTextView.text = "קוד משחק: $gameId"
                    gameIdTextView.visibility = View.VISIBLE
                    Toast.makeText(this, "משחק חדש נוצר! קוד: $gameId", Toast.LENGTH_LONG).show()
                }
            }
        } catch (e: Exception) {
            Log.e("Backgammon", "Error creating game: ${e.message}", e)
            runOnUiThread {
                Toast.makeText(this, "שגיאה ביצירת משחק: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
    
    private fun showJoinGameDialog() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("הצטרף למשחק")
        
        val input = EditText(this)
        input.hint = "הכנס קוד משחק"
        builder.setView(input)
        
        builder.setPositiveButton("הצטרף") { dialog, _ ->
            val gameId = input.text.toString().trim()
            if (gameId.isNotEmpty()) {
                joinGame(gameId)
            } else {
                Toast.makeText(this, "קוד משחק לא תקין", Toast.LENGTH_SHORT).show()
            }
            dialog.dismiss()
        }
        
        builder.setNegativeButton("ביטול") { dialog, _ ->
            dialog.cancel()
        }
        
        builder.show()
    }
    
    private fun joinGame(gameId: String) {
        try {
            Toast.makeText(this, "מתחבר למשחק...", Toast.LENGTH_SHORT).show()
            MultiplayerManager.joinGame(playerId, gameId) {
                Log.d("Backgammon", "Joined game: $gameId")
                runOnUiThread {
                    gameIdTextView.text = "קוד משחק: $gameId"
                    gameIdTextView.visibility = View.VISIBLE
                    Toast.makeText(this, "הצטרפת למשחק!", Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            Log.e("Backgammon", "Error joining game: ${e.message}", e)
            runOnUiThread {
                Toast.makeText(this, "שגיאה בהצטרפות למשחק: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
}