package com.medivault.medivault

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * Fires at the scheduled medication time (and every follow-up).
 * Speaks the tablet name via TTS, shows a persistent notification
 * with Taken / Not Now / Remind Later action buttons, then
 * schedules a follow-up alarm so it repeats until acknowledged.
 */
class TtsAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "TtsAlarmReceiver"
        const val EXTRA_MEDICINE_NAME = "medicine_name"
        const val EXTRA_HOUR = "hour"
        const val EXTRA_MINUTE = "minute"
        const val EXTRA_REMINDER_ID = "reminder_id"
        private const val CHANNEL_ID = "medivault_tts_reminders"
        private const val CHANNEL_NAME = "Medication TTS Reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()  // Keep receiver alive for TTS

        val id = intent.getIntExtra(EXTRA_REMINDER_ID, -1)
        val medicineName = intent.getStringExtra(EXTRA_MEDICINE_NAME) ?: "your medicine"
        val hour = intent.getIntExtra(EXTRA_HOUR, 0)
        val minute = intent.getIntExtra(EXTRA_MINUTE, 0)

        // If already acknowledged (user tapped Taken / Not Now), don't fire.
        if (id >= 0 && TtsAlarmScheduler.isAcknowledged(context, id)) {
            Log.d(TAG, "Alarm #$id already acknowledged — silent")
            pendingResult.finish()
            return
        }

        // Reset acknowledgement for daily alarms (fresh day = fresh reminder).
        val isFollowUp = intent.action?.contains("FOLLOWUP") == true
        if (!isFollowUp && id >= 0) {
            TtsAlarmScheduler.resetAcknowledgement(context, id)
        }

        // Build speech text.
        val period = if (hour >= 12) "PM" else "AM"
        val displayHour = when {
            hour == 0 -> 12
            hour > 12 -> hour - 12
            else -> hour
        }
        val displayMin = String.format("%02d", minute)
        val speech = "Time to take $medicineName at $displayHour:$displayMin $period"

        Log.d(TAG, "TTS alarm fired (#$id): $speech")

        // Show notification with action buttons FIRST (silent — TTS is the alert).
        if (id >= 0) {
            showNotification(context, id, medicineName, hour, minute)
        }

        // Schedule follow-up (will be skipped if user acknowledges).
        if (id >= 0) {
            TtsAlarmScheduler.scheduleAutoFollowUp(context, id, medicineName, hour, minute)
        }

        // Speak using Android native TTS.
        // Use a background thread with short delay, then create TTS on main looper.
        Thread {
            try {
                Thread.sleep(500) // let notification settle

                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                mainHandler.post {
                    var tts: TextToSpeech? = null
                    tts = TextToSpeech(context.applicationContext) { status ->
                        if (status == TextToSpeech.SUCCESS) {
                            tts?.language = Locale.US
                            tts?.setSpeechRate(0.9f)
                            tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                                override fun onStart(utteranceId: String?) {
                                    Log.d(TAG, "TTS started speaking: $utteranceId")
                                }
                                override fun onDone(utteranceId: String?) {
                                    Log.d(TAG, "TTS done: $utteranceId")
                                    tts?.shutdown()
                                    try { pendingResult.finish() } catch (_: Exception) {}
                                }
                                @Deprecated("Deprecated in Java")
                                override fun onError(utteranceId: String?) {
                                    Log.e(TAG, "TTS error: $utteranceId")
                                    tts?.shutdown()
                                    try { pendingResult.finish() } catch (_: Exception) {}
                                }
                            })
                            tts?.speak(speech, TextToSpeech.QUEUE_FLUSH, null, "med_alarm_$id")
                            Log.d(TAG, "TTS speak() called: $speech")
                        } else {
                            Log.e(TAG, "TTS init failed with status: $status")
                            try { pendingResult.finish() } catch (_: Exception) {}
                        }
                    }
                }

                // Safety timeout: finish pending result after 15s even if TTS hangs.
                Thread.sleep(15000)
                try { pendingResult.finish() } catch (_: Exception) {}
            } catch (e: Exception) {
                Log.e(TAG, "TTS thread error: ${e.message}")
                try { pendingResult.finish() } catch (_: Exception) {}
            }
        }.start()
    }

    private fun showNotification(
        context: Context, id: Int, name: String, hour: Int, minute: Int
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Ensure channel exists (required on API 26+).
        // NOTE: Sound is DISABLED on the channel because TTS is the audio alert.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily medication reminder alerts"
                enableVibration(true)
                setSound(null, null)  // silent — TTS handles audio
            }
            nm.createNotificationChannel(channel)
        }

        val period = if (hour >= 12) "PM" else "AM"
        val dispH = if (hour == 0) 12 else if (hour > 12) hour - 12 else hour
        val dispM = String.format("%02d", minute)
        val mealText = "Stay on schedule!"
        val bodyText = "Time for $name at $dispH:$dispM $period. $mealText"

        // ── Action PendingIntents ──────────────────────────────────────
        val takenIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_TAKEN
            putExtra(NotificationActionReceiver.EXTRA_REMINDER_ID, id)
            putExtra(NotificationActionReceiver.EXTRA_MEDICINE_NAME, name)
            putExtra(NotificationActionReceiver.EXTRA_HOUR, hour)
            putExtra(NotificationActionReceiver.EXTRA_MINUTE, minute)
        }
        val takenPi = PendingIntent.getBroadcast(
            context, id * 10 + 1, takenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notWillingIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_NOT_WILLING
            putExtra(NotificationActionReceiver.EXTRA_REMINDER_ID, id)
            putExtra(NotificationActionReceiver.EXTRA_MEDICINE_NAME, name)
            putExtra(NotificationActionReceiver.EXTRA_HOUR, hour)
            putExtra(NotificationActionReceiver.EXTRA_MINUTE, minute)
        }
        val notWillingPi = PendingIntent.getBroadcast(
            context, id * 10 + 2, notWillingIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val remindIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_REMIND_LATER
            putExtra(NotificationActionReceiver.EXTRA_REMINDER_ID, id)
            putExtra(NotificationActionReceiver.EXTRA_MEDICINE_NAME, name)
            putExtra(NotificationActionReceiver.EXTRA_HOUR, hour)
            putExtra(NotificationActionReceiver.EXTRA_MINUTE, minute)
        }
        val remindPi = PendingIntent.getBroadcast(
            context, id * 10 + 3, remindIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Build & show notification ─────────────────────────────────
        // Cancel first so Android treats re-post as a NEW notification.
        nm.cancel(id)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("\uD83D\uDC8A Time for $name")
            .setContentText(bodyText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_VIBRATE) // vibrate only, no sound
            .setSound(null) // no sound — TTS handles audio
            .setOnlyAlertOnce(false)  // vibrate every time
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(0, "✅ Taken", takenPi)
            .addAction(0, "❌ Not Now", notWillingPi)
            .addAction(0, "⏰ Remind Later", remindPi)
            .build()

        nm.notify(id, notification)
        Log.d(TAG, "Notification shown for #$id with action buttons")
    }
}
