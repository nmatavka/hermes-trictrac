package com.emredogan.tavlazari

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaPlayer
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.view.animation.AnimationUtils
import androidx.appcompat.app.AppCompatActivity
import com.emredogan.tavlazari.Utils.Util
import kotlinx.android.synthetic.main.activity_main.*
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

var isDialogVisible: Boolean = false


class MainActivity : AppCompatActivity(), SensorEventListener {
    private val delay_time_dice: Long = 600
    private val tag: String = MainActivity::class.java.getName()

    private lateinit var sensorManager: SensorManager

    // acceleration apart from gravity
    private var mAccel =
        0f

    // current acceleration including gravity
    private var mAccelCurrent =
        0f

    // last acceleration including gravity
    private var mAccelLast =
        0f
    private lateinit var mediaPlayer: MediaPlayer
    private var isRolling = false
    private var numberOfDicesRolled = 0
    private var randomNumber1 = 1
    private var randomNumber2 = 1

    private val versionCode = BuildConfig.VERSION_CODE


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        sensorManager.registerListener(
            mSensorListener,
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            SensorManager.SENSOR_DELAY_NORMAL
        )
        mAccel = 0.00f
        mAccelCurrent = SensorManager.GRAVITY_EARTH
        mAccelLast = SensorManager.GRAVITY_EARTH

        result_image.setImageResource(R.drawable.dice_1)
        result_image2.setImageResource(R.drawable.dice_1)

        roll_button.setOnClickListener {
            rollDice()
        }
        if (!prefs.dontShowIntro) {
            if(!isRunningTest()) {
                Util.showIntroductionDialogue(this)
            }
        }
    }


    private val mSensorListener: SensorEventListener = object : SensorEventListener {
        override fun onSensorChanged(se: SensorEvent) {
            val x = se.values[0]
            val y = se.values[1]
            val z = se.values[2]
            mAccelLast = mAccelCurrent
            mAccelCurrent =
                sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            val delta = mAccelCurrent - mAccelLast
            mAccel = mAccel * 0.9f + delta // perform low-cut filter
            if (mAccel > 12) {
                rollDice()
            }
        }

        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
            Log.d(tag, "Accuracy change $accuracy")
        }
    }

    override fun onResume() {
        super.onResume()
        mediaPlayer = MediaPlayer.create(applicationContext, R.raw.dice_sound)
        sensorManager.registerListener(
            mSensorListener,
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            SensorManager.SENSOR_DELAY_NORMAL
        )
    }

    override fun onPause() {
        sensorManager.unregisterListener(mSensorListener)
        mediaPlayer.stop()
        mediaPlayer.reset()
        mediaPlayer.release()
        super.onPause()
    }

    private fun rollDice() {
        if (!isRolling && !isDialogVisible) {
            val prevDiceText: String = String.format(
                resources.getString(R.string.previous_dice_string), randomNumber1, randomNumber2
            )
            previousDiceText.text = prevDiceText

            isRolling = true
            startRollAnimation()

            roll_button.isClickable = false
            roll_button.setBackgroundColor(resources.getColor(R.color.colorRed))
            mediaPlayer.start()


            randomNumber1 = Util.createRandomNumbersForDice(6)
            randomNumber2 = Util.createRandomNumbersForDice(6)

            stopRollAnimation()
            numberOfDicesRolled++
        }
    }

    private fun setSecondDiceResource() {
        val resourceId2 = when (randomNumber2) {
            1 -> R.drawable.dice_1
            2 -> R.drawable.dice_2
            3 -> R.drawable.dice_3
            4 -> R.drawable.dice_4
            5 -> R.drawable.dice_5
            6 -> R.drawable.dice_6
            else -> R.drawable.dice_3
        }
        result_image2.setImageResource(resourceId2)
    }

    private fun setFirstDiceResource() {
        val resourceId1 = when (randomNumber1) {
            1 -> R.drawable.dice_1
            2 -> R.drawable.dice_2
            3 -> R.drawable.dice_3
            4 -> R.drawable.dice_4
            5 -> R.drawable.dice_5
            6 -> R.drawable.dice_6
            else -> R.drawable.dice_3
        }

        result_image.setImageResource(resourceId1)
    }

    private fun startRollAnimation() {
        result_image.startAnimation(AnimationUtils.loadAnimation(this, R.anim.anim))
        result_image2.startAnimation(AnimationUtils.loadAnimation(this, R.anim.anim))
    }

    private fun stopRollAnimation() {
        Handler().postDelayed({ result_image.clearAnimation() }, delay_time_dice)
        Handler().postDelayed({
            setFirstDiceResource()
            setSecondDiceResource()
            result_image2.clearAnimation()
            roll_button.isClickable = true
            roll_button.setBackgroundColor(resources.getColor(R.color.colorGrey))
            isRolling = false
        }, delay_time_dice)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        TODO("Not yet implemented")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        TODO("Not yet implemented")
    }

    private var isRunningTest: AtomicBoolean? = null

    @Synchronized
    fun isRunningTest(): Boolean {
        if (null == isRunningTest) {
            val istest: Boolean
            istest = try {
                Class.forName("androidx.test.espresso.Espresso")
                true
            } catch (e: ClassNotFoundException) {
                false
            }
            isRunningTest = AtomicBoolean(istest)
        }
        return isRunningTest!!.get()
    }
}
