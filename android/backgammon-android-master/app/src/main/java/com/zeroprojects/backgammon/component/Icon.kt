package com.zeroprojects.backgammon.component

import android.content.Context
import android.content.res.TypedArray
import android.graphics.PorterDuff
import android.net.Uri
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageView
import com.zeroprojects.backgammon.utils.LocalController
import com.squareup.picasso.Picasso
import com.zeroprojects.backgammon.R
import java.io.File

class Icon @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatImageView (context, attrs, defStyleAttr) {


    init {
        if (!isInEditMode) {
            attrs?.let {
                val a: TypedArray = context.obtainStyledAttributes(attrs, R.styleable.Icon, defStyleAttr, 0)
                val color = a.getColor(R.styleable.Icon_color, 0)
                if (color != 0) {
                    setColorFilter(color, PorterDuff.Mode.SRC_ATOP)
                }
                invalidate()
                a.recycle()
            }

        }
    }

    fun setColor(color: Int) {
        if (color != 0) {
            setColorFilter(LocalController.getColor(color), PorterDuff.Mode.SRC_ATOP)
        }
        invalidate()
    }

    fun load(uri: Uri) {
        Picasso.get().load(uri).into(this)
    }

    fun load(file: File) {
        Picasso.get().load(file).into(this)
    }

    fun load(path: String) {
        Picasso.get().load(path).into(this)
    }

    fun load(resourceId: Int) {
        Picasso.get().load(resourceId).into(this)
    }

}