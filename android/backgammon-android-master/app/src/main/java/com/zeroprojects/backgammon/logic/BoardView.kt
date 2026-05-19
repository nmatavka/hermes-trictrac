package com.zeroprojects.backgammon.logic

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.RelativeLayout
import androidx.annotation.ColorRes
import androidx.core.content.ContextCompat
import androidx.core.view.marginBottom
import com.squareup.picasso.Picasso
import com.zeroprojects.backgammon.R
import com.zeroprojects.backgammon.base.ApplicationLoader
import com.zeroprojects.backgammon.utils.DimensionUtils
import com.zeroprojects.backgammon.utils.ThemeHelper

class BoardView(context: Context, attrs: AttributeSet? = null) : RelativeLayout(context, attrs) {

    lateinit var middleDivider: LinearLayout
    lateinit var diceOne: DiceView
    lateinit var diceTwo: DiceView

    init {
        Picasso.get()
            .load(R.drawable.ic_board_bg)
            .into(object : com.squareup.picasso.Target {
                override fun onBitmapLoaded(bitmap: Bitmap?, from: Picasso.LoadedFrom?) {
                    // Set the bitmap as the background
                    background = BitmapDrawable(resources, bitmap)
                    background = getDrawableBackground()
                }

                override fun onBitmapFailed(e: Exception?, errorDrawable: Drawable?) {
                    // Handle failure, if needed
                }

                override fun onPrepareLoad(placeHolderDrawable: Drawable?) {
                    // Handle loading preparation, if needed
                }
            })
        addDivider()
        addBarContainer()
        invalidate()
    }

    private fun getDrawableBackground(): GradientDrawable {
        val gradientDrawable = GradientDrawable()
        gradientDrawable.shape = GradientDrawable.RECTANGLE
        gradientDrawable.setColor(ContextCompat.getColor(context, R.color.white))
        gradientDrawable.setStroke(
            DimensionUtils.dpToPx(50f),
            ContextCompat.getColor(context, R.color.wall_color)
        )
        return gradientDrawable
    }
    //200 100

    private fun addDivider() {
        middleDivider = LinearLayout(context).apply {
            id = View.generateViewId()
            val gradientDrawable = GradientDrawable()
            gradientDrawable.shape = GradientDrawable.RECTANGLE
            gradientDrawable.setColor(ContextCompat.getColor(context, R.color.wall_color))
            background = gradientDrawable
            val layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                DimensionUtils.dpToPx(200f)
            ).apply {
                gravity = Gravity.CENTER  // Center vertically within the LinearLayout
            }
            layoutParams.addRule(CENTER_IN_PARENT)
            this.layoutParams = layoutParams
        }
        addDiceOne()
        addDiceTwo()
        addView(middleDivider)
        middleDivider.orientation = LinearLayout.HORIZONTAL
    }

    private fun addBarContainer() {
        var container = LinearLayout(context).apply {
            id = View.generateViewId()
            val layoutParams = LayoutParams(
                DimensionUtils.getDisplayWidthInPixel() / 2 - (DimensionUtils.dpToPx(50f)),
                LayoutParams.MATCH_PARENT
            ).apply {
                marginStart = DimensionUtils.dpToPx(50f)
                bottomMargin = DimensionUtils.dpToPx(50f)
            }
            layoutParams.addRule(BELOW, middleDivider.id)
            orientation = LinearLayout.VERTICAL
            this.layoutParams = layoutParams
        }
        addBarView(container)
        addBarView(container)
        addBarView(container)
        addBarView(container)
        addBarView(container)
        addBarView(container)
        addView(container)
    }

    private fun addBarView(parent:LinearLayout){
        var barView = BarView(context).apply {
            id = View.generateViewId()
            val layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                ((DimensionUtils.getDisplayHeightInPixel() /2)- 300) /6
            ).apply {
            }
            this.layoutParams = layoutParams
        }
        parent.addView(barView)
    }

    private fun addDiceOne() {
        diceOne = DiceView(context).apply {
            id = View.generateViewId()

            val layoutParams = LinearLayout.LayoutParams(
                DimensionUtils.dpToPx(100f),
                DimensionUtils.dpToPx(100f)
            ).apply {
                marginEnd = DimensionUtils.dpToPx(8f)
            }
            setDiceSize(100f)
            this.layoutParams = layoutParams
        }
        diceOne.roll()
        middleDivider.addView(diceOne)
    }


    private fun addDiceTwo() {
        diceTwo = DiceView(context).apply {
            id = View.generateViewId()
            val layoutParams = LinearLayout.LayoutParams(
                DimensionUtils.dpToPx(100f),
                DimensionUtils.dpToPx(100f)
            ).apply {
                marginStart = DimensionUtils.dpToPx(8f)
            }
            this.layoutParams = layoutParams
            setDiceSize(100f)
        }
        diceTwo.roll()
        middleDivider.addView(diceTwo)

    }


    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // Draw your lines here using the linePaint object
    }
}