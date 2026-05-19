package com.zeroprojects.backgammon.network

import com.google.gson.annotations.Expose
import com.google.gson.annotations.SerializedName

data class Result(

    @SerializedName("device")
    @Expose
    val device: String,


    )
