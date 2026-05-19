package com.zeroprojects.backgammon.logic

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import com.zeroprojects.backgammon.utils.DimensionUtils
import kotlin.random.Random

class DiceView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

    private val paint: Paint = Paint()
    private var dotRadius = 15f
    private var bgRadius = 10f
    private var diceSize = 150f
    private var dotOffset = 36f
    private var bgRect = RectF()
    private var number : Int = 0

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        bgRect.set(0f, 0f, diceSize, diceSize)

        paint.color = Color.WHITE
        paint.style = Paint.Style.FILL
        paint.setShadowLayer(bgRadius, 0f, 0f, Color.GRAY)
        canvas.drawRoundRect(bgRect, bgRadius, bgRadius, paint)
        paint.clearShadowLayer()

        paint.color = Color.BLACK
        paint.style = Paint.Style.FILL
        drawDots(canvas, number) // Top left and bottom right
    }

    fun setDiceSize(size:Float){
        this.diceSize = size
        this.dotOffset = size / 4
    }

    fun getNumber():Int{
        return this.number;
    }

    fun roll(){
        number = Random.nextInt(1, 7);
        invalidate()
    }

    private fun drawDots(canvas: Canvas, number: Int) {

        when (number) {
            1 -> canvas.drawCircle(diceSize / 2, diceSize / 2, dotRadius, paint)
            2 -> {
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 , dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 , dotRadius, paint)
            }

            3 -> {
                canvas.drawCircle(diceSize / 2, diceSize / 2, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 , dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 , dotRadius, paint)
            }

            4 -> {
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 -dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 -dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 +dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 +dotOffset, dotRadius, paint)
            }

            5 -> {
                canvas.drawCircle(diceSize / 2, diceSize / 2, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 - dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 - dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 + dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 + dotOffset, dotRadius, paint)
            }

            6 -> {
                canvas.drawCircle(diceSize / 2 - dotOffset,diceSize / 2, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset,diceSize / 2, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 - dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 - dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 - dotOffset, diceSize / 2 + dotOffset, dotRadius, paint)
                canvas.drawCircle(diceSize / 2 + dotOffset, diceSize / 2 + dotOffset, dotRadius, paint)
            }
        }
    }
}
