package com.zeroprojects.backgammon.logic

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.zeroprojects.backgammon.R
import com.zeroprojects.backgammon.enums.StoneColor
import com.zeroprojects.backgammon.utils.DimensionUtils
import com.zeroprojects.backgammon.utils.LocalController
import kotlin.random.Random

class StoneView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

    private val mainCirclePaint: Paint = Paint()
    private val gradientCirclePaint: Paint = Paint()
    private var gradientShader: Shader? = null
    private var stoneColor: StoneColor = StoneColor.WHITE;
    private var currentPosition: Int = 0;
    private val gradientWhiteColors: IntArray by lazy {
        intArrayOf(
            ContextCompat.getColor(context, R.color.white_stone_start),
            ContextCompat.getColor(context, R.color.white_stone_end)
        )
    }
    private val gradientBlackColors: IntArray by lazy {
        intArrayOf(
            ContextCompat.getColor(context, R.color.black_stone_start),
            ContextCompat.getColor(context, R.color.black_stone_end)
        )
    }
    private val gradientPositions: FloatArray by lazy { floatArrayOf(0.0f, 1.0f) }

    fun setStoneColor(color: StoneColor) {
        this.stoneColor = color
        invalidate()
    }

    fun getStoneColor(): StoneColor {
        return this.stoneColor;
    }

    fun setPosition(position: Int) {
        this.currentPosition = position
    }

    fun getGradiantColors(): IntArray {
        return if (stoneColor == StoneColor.WHITE) gradientWhiteColors else gradientBlackColors
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val centerX = width / 2f
        val centerY = height / 2f
        val radius = (width.coerceAtMost(height) / 3).toFloat()

        // Create or update main circle gradient shader

        gradientShader = createLinearGradient(centerX, centerY, radius)

        mainCirclePaint.shader = gradientShader

        // Draw the main circle
        canvas.drawCircle(centerX, centerY, radius, mainCirclePaint)

        // Create gradient circle gradient shader
        val gradientCircleGradientShader = createRadialGradient(centerX, centerY, radius)
        gradientCirclePaint.shader = gradientCircleGradientShader

        // Draw the gradient circle
        canvas.drawCircle(centerX, centerY, radius / 1.5f, gradientCirclePaint)
    }


    private fun createLinearGradient(centerX: Float, centerY: Float, radius: Float): Shader {
        return LinearGradient(
            centerX - radius,
            centerY,
            centerX + radius,
            centerY,
            getGradiantColors(),
            gradientPositions,
            Shader.TileMode.CLAMP
        )
    }

    private fun createRadialGradient(centerX: Float, centerY: Float, radius: Float): Shader {
        return RadialGradient(
            centerX,
            centerY,
            radius / 2,
            getGradiantColors(),
            null,
            Shader.TileMode.CLAMP
        )
    }
}