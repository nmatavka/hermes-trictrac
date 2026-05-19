package com.zeroprojects.backgammon.network

import com.zeroprojects.backgammon.config.Conf
import okhttp3.RequestBody
import retrofit2.Call
import retrofit2.http.*

interface APIService {

    @POST(Conf.Path.V1_DEVICE_GENERATE)
    fun generateDevice(@Body body: RequestBody): Call<Response>

    @POST(Conf.Path.V1_ROOM_CREATE)
    fun createRoom(): Call<Response>
}
