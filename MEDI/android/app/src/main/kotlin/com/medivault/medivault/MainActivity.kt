package com.medivault.medivault

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.medivault.medivault/tts_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleTtsAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val name = call.argument<String>("name") ?: "your medicine"
                    val hour = call.argument<Int>("hour") ?: 0
                    val minute = call.argument<Int>("minute") ?: 0

                    TtsAlarmScheduler.schedule(this, id, name, hour, minute)
                    result.success(true)
                }
                "cancelTtsAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    TtsAlarmScheduler.cancel(this, id)
                    result.success(true)
                }
                "acknowledgeTtsAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    TtsAlarmScheduler.acknowledge(this, id)
                    result.success(true)
                }
                "setSnoozeDuration" -> {
                    val minutes = call.argument<Int>("minutes") ?: 5
                    TtsAlarmScheduler.setSnoozeDuration(this, minutes)
                    result.success(true)
                }
                "getSnoozeDuration" -> {
                    result.success(TtsAlarmScheduler.getSnoozeDuration(this))
                }
                else -> result.notImplemented()
            }
        }
    }
}
