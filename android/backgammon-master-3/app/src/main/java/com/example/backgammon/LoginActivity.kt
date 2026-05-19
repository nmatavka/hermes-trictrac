package com.example.backgammon

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class LoginActivity : AppCompatActivity() {
    
    private lateinit var userManager: UserManager
    private lateinit var scoreManager: ScoreManager
    private lateinit var nameEditText: EditText
    private lateinit var loginButton: Button
    private lateinit var playerStatsTextView: TextView
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)
        
        userManager = UserManager(this)
        scoreManager = ScoreManager()
        
        // בדיקה אם המשתמש כבר מחובר
        if (userManager.isLoggedIn()) {
            goToMainActivity()
            return
        }
        
        initViews()
        setupClickListeners()
    }
    
    private fun initViews() {
        nameEditText = findViewById(R.id.nameEditText)
        loginButton = findViewById(R.id.loginButton)
        playerStatsTextView = findViewById(R.id.playerStatsTextView)
    }
    
    private fun setupClickListeners() {
        loginButton.setOnClickListener {
            val playerName = nameEditText.text.toString().trim()
            if (playerName.isNotEmpty()) {
                if (playerName.length >= 2) {
                    loginPlayer(playerName)
                } else {
                    Toast.makeText(this, "השם חייב להכיל לפחות 2 תווים", Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(this, "אנא הכניסי את השם שלך", Toast.LENGTH_SHORT).show()
            }
        }
        
        nameEditText.setOnEditorActionListener { _, _, _ ->
            loginButton.performClick()
            true
        }
    }
    
    private fun loginPlayer(playerName: String) {
        loginButton.isEnabled = false
        loginButton.text = "מתחבר..."
        
        // קודם נטען את הנתונים של השחקן
        scoreManager.getPlayerScore(playerName) { playerScore ->
            runOnUiThread {
                if (playerScore != null) {
                    // שמירת השם ב-SharedPreferences
                    userManager.savePlayerName(playerName)
                    
                    // הצגת הנתונים הנוכחיים
                    val statsText = "שלום $playerName!\n" +
                            "ניצחונות: ${playerScore.wins}\n" +
                            "הפסדים: ${playerScore.losses}\n" +
                            "גביעים: ${playerScore.trophies}"
                    
                    playerStatsTextView.text = statsText
                    playerStatsTextView.visibility = TextView.VISIBLE
                    
                    Toast.makeText(this, "התחברת בהצלחה!", Toast.LENGTH_SHORT).show()
                    
                    // מעבר למשחק אחרי שניה
                    nameEditText.postDelayed({
                        goToMainActivity()
                    }, 1500)
                } else {
                    Toast.makeText(this, "שגיאה בחיבור לשרת", Toast.LENGTH_SHORT).show()
                    loginButton.isEnabled = true
                    loginButton.text = "כניסה"
                }
            }
        }
    }
    
    private fun goToMainActivity() {
        val intent = Intent(this, MainActivity::class.java)
        startActivity(intent)
        finish()
    }
} 