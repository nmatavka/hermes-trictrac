package com.zeroprojects.backgammon

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import com.zeroprojects.backgammon.base.BaseActivity
import com.zeroprojects.backgammon.databinding.ActivityMainBinding
import com.zeroprojects.backgammon.enums.StoneColor

class MainActivity : BaseActivity<ActivityMainBinding>() {
    override fun getLayoutResourceId(): Int {
        return R.layout.activity_main;
    }

    override fun onBackPress() {
        TODO("Not yet implemented")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding.root.setOnClickListener {

        }
    }
}