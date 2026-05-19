package com.example.myapplication22

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class ResultActivity : AppCompatActivity() {

    private lateinit var winnerBtn: Button
    private lateinit var resetBtn: Button
    private lateinit var winnerSuffix: TextView
    private lateinit var congratsImage: ImageView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_result)

        winnerBtn = findViewById(R.id.winnerButton)
        resetBtn = findViewById(R.id.resetGameButton)
        winnerSuffix = findViewById(R.id.winnerSuffix)
        congratsImage = findViewById(R.id.congratsImage)

        val winner = intent.getStringExtra("WINNER_NAME") ?: "Player"

        // winner ismini butona koy
        winnerBtn.text = winner

        resetBtn.setOnClickListener {
            // MainActivity'i yeniden başlat ve ResultActivity'yi bitir.
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            finish()
        }
    }
}
