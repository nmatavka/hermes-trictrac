package com.emredogan.tavlazari

import android.content.Context
import android.content.SharedPreferences

private const val PREFERENCE_NAME = "SharedPreferenceExample"
private const val PREFERENCE_INTRO_DONT_SHOW = "INTRO_DONT_SHOW"

class SharedPrefs(context: Context) {
    private val preference: SharedPreferences = context.getSharedPreferences(PREFERENCE_NAME, Context.MODE_PRIVATE)

    var dontShowIntro: Boolean
        get() = preference.getBoolean(PREFERENCE_INTRO_DONT_SHOW, false)
        set(value) = preference.edit().putBoolean(PREFERENCE_INTRO_DONT_SHOW, value).apply()
}
