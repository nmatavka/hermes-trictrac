package com.example.myapplication22

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var edit1: EditText
    private lateinit var edit2: EditText
    private lateinit var startBtn: Button
    private lateinit var btnP1: Button
    private lateinit var btnP2: Button
    private lateinit var scoreText: TextView

    private var score1 = 0
    private var score2 = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val toolbar: androidx.appcompat.widget.Toolbar = findViewById(R.id.toolbar)
        setSupportActionBar(toolbar)

        edit1 = findViewById(R.id.editText1)
        edit2 = findViewById(R.id.editText2)
        startBtn = findViewById(R.id.startGameButton)
        btnP1 = findViewById(R.id.button1)
        btnP2 = findViewById(R.id.button2)
        scoreText = findViewById(R.id.scoreText)

        resetGame()

        startBtn.setOnClickListener {
            val name1 = edit1.text.toString().trim()
            val name2 = edit2.text.toString().trim()

            if (name1.isEmpty() || name2.isEmpty()) {
                if (name1.isEmpty()) edit1.error = getString(R.string.player1_hint)
                if (name2.isEmpty()) edit2.error = getString(R.string.player2_hint)
                return@setOnClickListener
            }

            btnP1.text = getString(R.string.player_wins, name1)
            btnP2.text = getString(R.string.player_wins, name2)

            edit1.isEnabled = false
            edit2.isEnabled = false
            btnP1.isEnabled = true
            btnP2.isEnabled = true

            score1 = 0
            score2 = 0
            updateScoreText()
            startBtn.isEnabled = false
        }

        btnP1.setOnClickListener {
            score1++
            updateScoreText()
            checkWinner(btnP1.text.toString())
        }

        btnP2.setOnClickListener {
            score2++
            updateScoreText()
            checkWinner(btnP2.text.toString())
        }
    }

    private fun updateScoreText() {
        scoreText.text = getString(R.string.score_format, score1, score2)
    }

    private fun checkWinner(buttonText: String) {
        if (score1 >= 5 || score2 >= 5) {
            val winner = buttonText.substringBefore(" wins").trim()
            val intent = Intent(this, ResultActivity::class.java)
            intent.putExtra("WINNER_NAME", winner)
            startActivity(intent)
        }
    }

    private fun resetGame() {
        edit1.text.clear()
        edit2.text.clear()
        edit1.isEnabled = true
        edit2.isEnabled = true
        btnP1.isEnabled = false
        btnP2.isEnabled = false
        startBtn.isEnabled = true
        score1 = 0
        score2 = 0
        updateScoreText()
        btnP1.text = getString(R.string.player_wins, getString(R.string.player1_hint))
        btnP2.text = getString(R.string.player_wins, getString(R.string.player2_hint))
    }
}
