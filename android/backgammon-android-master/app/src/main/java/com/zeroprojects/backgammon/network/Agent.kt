package com.zeroprojects.backgammon.network

import com.zeroprojects.backgammon.config.Conf
import com.zeroprojects.backgammon.utils.DeviceUtils
import okhttp3.FormBody
import okhttp3.RequestBody
import retrofit2.Call
import java.util.Objects


object Agent {

    object Device {



    }

    object Room {
        fun create(): Call<Response> {
            return RetrofitClient.getNetworkConfiguration().createRoom()
        }
    }


}