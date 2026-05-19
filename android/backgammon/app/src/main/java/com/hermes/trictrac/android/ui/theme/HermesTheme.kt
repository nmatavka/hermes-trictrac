package com.hermes.trictrac.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.fontResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.hermes.trictrac.android.R

private val Gold = Color(0xFFD8B277)
private val Ink = Color(0xFFF8ECD7)
private val Wood = Color(0xFF2D100B)
private val Walnut = Color(0xFF180705)
private val Card = Color(0xFFD8B277)
private val FeltDark = Color(0xFF5B2414)
private val FeltLight = Color(0xFFE4B66A)
private val AccentGreen = Color(0xFF5CB680)
private val AccentRed = Color(0xFFD46B55)

private val BodyFamily = FontFamily(
    Font(R.font.jura, FontWeight.Normal),
    Font(R.font.jura, FontWeight.Medium),
    Font(R.font.jura, FontWeight.Bold),
)

private val DisplayFamily = FontFamily(
    Font(R.font.tektur, FontWeight.Normal),
    Font(R.font.tektur, FontWeight.Medium),
    Font(R.font.tektur, FontWeight.Bold),
)

private val NumericFamily = FontFamily(
    Font(R.font.oxanium, FontWeight.Normal),
    Font(R.font.oxanium, FontWeight.Medium),
    Font(R.font.oxanium, FontWeight.Bold),
)

private val AccentFamily = FontFamily(
    Font(R.font.orbitron, FontWeight.Medium),
    Font(R.font.orbitron, FontWeight.Bold),
)

private val ColorScheme = darkColorScheme(
    primary = Gold,
    secondary = AccentGreen,
    tertiary = FeltLight,
    background = Walnut,
    surface = Wood,
    surfaceVariant = FeltDark,
    onPrimary = Walnut,
    onSecondary = Walnut,
    onTertiary = Walnut,
    onBackground = Ink,
    onSurface = Ink,
    onSurfaceVariant = Ink,
    error = AccentRed,
    onError = Ink,
)

@Composable
fun HermesTrictracTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ColorScheme,
        typography = androidx.compose.material3.Typography(
            displayLarge = TextStyle(
                fontFamily = DisplayFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 34.sp,
                letterSpacing = 0.2.sp,
            ),
            displayMedium = TextStyle(
                fontFamily = DisplayFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 28.sp,
            ),
            headlineMedium = TextStyle(
                fontFamily = DisplayFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 24.sp,
            ),
            titleLarge = TextStyle(
                fontFamily = AccentFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 20.sp,
            ),
            titleMedium = TextStyle(
                fontFamily = BodyFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
            ),
            bodyLarge = TextStyle(
                fontFamily = BodyFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 16.sp,
            ),
            bodyMedium = TextStyle(
                fontFamily = BodyFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
            ),
            bodySmall = TextStyle(
                fontFamily = BodyFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
            ),
            labelLarge = TextStyle(
                fontFamily = BodyFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
            ),
            labelMedium = TextStyle(
                fontFamily = NumericFamily,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
            ),
        ),
        content = content,
    )
}

object HermesColors {
    val Gold = Gold
    val Ink = Ink
    val Wood = Wood
    val Walnut = Walnut
    val Card = Color(0xFF220C08)
    val CardBorder = Color(0x48D8B277)
    val FeltDark = FeltDark
    val FeltLight = FeltLight
    val AccentGreen = AccentGreen
    val AccentRed = AccentRed
}
