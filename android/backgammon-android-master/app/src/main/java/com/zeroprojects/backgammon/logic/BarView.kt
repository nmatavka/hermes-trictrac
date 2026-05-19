package com.zeroprojects.backgammon.logic

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.graphics.*

class BarView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

    private val rectPaint = Paint().apply {
        color = Color.TRANSPARENT
        style = Paint.Style.FILL
    }

    private val trianglePaint = Paint().apply {
        color = Color.RED // Color of the triangle
        style = Paint.Style.FILL
    }

    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val rectWidth = width.toFloat() // Width of the rectangle
        val rectHeight = height.toFloat() // Height of the rectangle
        val rectLeft = 0f // Left position of the rectangle
        val rectTop = (height - rectHeight) / 2 // Top position of the rectangle
        val rectRight = rectLeft + rectWidth // Right position of the rectangle
        val rectBottom = rectTop + rectHeight // Bottom position of the rectangle


        // Draw the transparent rectangle
        canvas.drawRect(rectLeft, rectTop, rectRight, rectBottom, rectPaint)

        // Update trianglePaint color and style if needed
        trianglePaint.color = Color.RED // Color of the triangle
        trianglePaint.style = Paint.Style.FILL

        // Update path for the triangle
        path.reset()
        path.moveTo(rectRight - rectWidth / 2, rectTop + rectHeight / 2) // Right center of the rectangle
        path.lineTo(rectLeft, rectTop) // Top left corner of the rectangle
        path.lineTo(rectLeft, rectBottom) // Bottom left corner of the rectangle
        path.close() // Close the path to form a triangle

        // Draw the triangle
        canvas.drawPath(path, trianglePaint)
    }
}