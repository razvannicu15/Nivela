package ro.noraz.nivela

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Accelerometer stream, vibration, beeps, keep-screen-on and sharing for Nivela. */
class MainActivity : FlutterActivity() {
    private var tone: ToneGenerator? = null
    private var sensorListener: SensorEventListener? = null
    private var accuracy = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "nivela/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "keepOn" -> {
                    if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "vibrate" -> {
                    vibrate(((call.arguments as? Number)?.toLong() ?: 40L).coerceIn(5L, 500L))
                    result.success(null)
                }
                "beep" -> {
                    beep(call.arguments as? String ?: "level")
                    result.success(null)
                }
                "share" -> {
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, call.arguments as? String ?: "")
                    }
                    startActivity(Intent.createChooser(send, null))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "nivela/sensor").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                // Gravity (accelerometer fused with the gyroscope) ignores hand shake;
                // fall back to the raw accelerometer on phones without it.
                val acc = sm.getDefaultSensor(Sensor.TYPE_GRAVITY) ?: sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                if (acc == null) {
                    events.error("no_sensor", "No accelerometer", null)
                    return
                }
                val l = object : SensorEventListener {
                    override fun onSensorChanged(e: SensorEvent) {
                        events.success(doubleArrayOf(e.values[0].toDouble(), e.values[1].toDouble(), e.values[2].toDouble(), accuracy.toDouble()))
                    }

                    override fun onAccuracyChanged(s: Sensor?, a: Int) {
                        accuracy = a
                    }
                }
                sensorListener = l
                sm.registerListener(l, acc, SensorManager.SENSOR_DELAY_GAME)
            }

            override fun onCancel(arguments: Any?) {
                val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                sensorListener?.let { sm.unregisterListener(it) }
                sensorListener = null
            }
        })
    }

    private fun vibrate(ms: Long) {
        val v: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= 26) {
            v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(ms)
        }
    }

    private fun beep(kind: String) {
        try {
            val t = tone ?: ToneGenerator(AudioManager.STREAM_MUSIC, 80).also { tone = it }
            when (kind) {
                "lock" -> t.startTone(ToneGenerator.TONE_PROP_ACK, 180)
                "tick" -> t.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
                else -> t.startTone(ToneGenerator.TONE_PROP_BEEP2, 160)
            }
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
