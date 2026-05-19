package com.hermes.trictrac.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import com.hermes.trictrac.android.ui.HermesTrictracApp
import com.hermes.trictrac.android.ui.theme.HermesTrictracTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        setContent {
            HermesTrictracTheme {
                HermesTrictracApp()
            }
        }
    }
}
