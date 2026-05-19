package com.example.backgammon

import android.content.Context
import android.content.SharedPreferences

class UserManager(context: Context) {
    companion object {
        private const val PREFS_NAME = "BackgammonUserPrefs"
        private const val KEY_PLAYER_NAME = "player_name"
        private const val KEY_IS_LOGGED_IN = "is_logged_in"
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    fun savePlayerName(name: String) {
        prefs.edit()
            .putString(KEY_PLAYER_NAME, name)
            .putBoolean(KEY_IS_LOGGED_IN, true)
            .apply()
    }
    
    fun getPlayerName(): String? {
        return prefs.getString(KEY_PLAYER_NAME, null)
    }
    
    fun isLoggedIn(): Boolean {
        return prefs.getBoolean(KEY_IS_LOGGED_IN, false) && getPlayerName() != null
    }
    
    fun logout() {
        prefs.edit()
            .remove(KEY_PLAYER_NAME)
            .putBoolean(KEY_IS_LOGGED_IN, false)
            .apply()
    }
} 