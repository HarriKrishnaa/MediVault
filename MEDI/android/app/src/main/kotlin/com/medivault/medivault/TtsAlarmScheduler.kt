package com.medivault.medivault

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Schedules / cancels TTS alarms and follow-up repeats via AlarmManager.
 * Uses SharedPreferences to track whether a reminder has been acknowledged.
 */
object TtsAlarmScheduler {

    private const val TAG = "TtsAlarmScheduler"
    private const val PREFS_NAME = "tts_alarm_prefs"
    private const val KEY_SNOOZE_MINUTES = "snooze_minutes"
    private const val DEFAULT_SNOOZE_MINUTES = 5
    private const val AUTO_REPEAT_MS = 1 * 60 * 1000L  // 1 min auto-repeat when ignored

    // ── Daily alarm ──────────────────────────────────────────────────────

    fun schedule(context: Context, id: Int, name: String, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = buildIntent(context, id, name, hour, minute)
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        // Clear any previous acknowledgement for this id.
        resetAcknowledgement(context, id)

        try {
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pendingIntent
            )
            Log.d(TAG, "✅ Scheduled daily TTS alarm #$id for $name at $hour:$minute")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule TTS alarm #$id: ${e.message}")
        }
    }

    // ── Auto follow-up (1 min when user ignores notification) ────────────

    fun scheduleAutoFollowUp(context: Context, id: Int, name: String, hour: Int, minute: Int) {
        scheduleFollowUpInternal(context, id, name, hour, minute, AUTO_REPEAT_MS, "1 min (auto)")
    }

    // ── Remind Later follow-up (user-configurable, default 5 min) ──────

    fun scheduleFollowUp(context: Context, id: Int, name: String, hour: Int, minute: Int) {
        val snoozeMs = getSnoozeDuration(context) * 60 * 1000L
        val label = "${getSnoozeDuration(context)} min (remind later)"
        scheduleFollowUpInternal(context, id, name, hour, minute, snoozeMs, label)
    }

    private fun scheduleFollowUpInternal(
        context: Context, id: Int, name: String, hour: Int, minute: Int,
        delayMs: Long, label: String
    ) {
        if (isAcknowledged(context, id)) {
            Log.d(TAG, "Alarm #$id already acknowledged — skipping follow-up")
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = buildIntent(context, id, name, hour, minute).apply {
            action = "com.medivault.TTS_FOLLOWUP_$id"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, id + 100000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerAt = System.currentTimeMillis() + delayMs
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
            )
            Log.d(TAG, "⏰ Follow-up alarm #$id in $label")
        } catch (e: Exception) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            Log.d(TAG, "⏰ Follow-up alarm #$id (inexact) in $label")
        }
    }

    fun cancelFollowUp(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TtsAlarmReceiver::class.java).apply {
            action = "com.medivault.TTS_FOLLOWUP_$id"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, id + 100000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled follow-up for #$id")
    }

    // ── Acknowledgement (SharedPreferences) ──────────────────────────────

    fun acknowledge(context: Context, id: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putBoolean("ack_$id", true).apply()
        cancelFollowUp(context, id)
        Log.d(TAG, "✅ Acknowledged alarm #$id")
    }

    fun isAcknowledged(context: Context, id: Int): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("ack_$id", false)
    }

    fun resetAcknowledgement(context: Context, id: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove("ack_$id").apply()
    }

    // ── Snooze duration (configurable) ────────────────────────────────

    fun setSnoozeDuration(context: Context, minutes: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putInt(KEY_SNOOZE_MINUTES, minutes).apply()
        Log.d(TAG, "Snooze duration set to $minutes min")
    }

    fun getSnoozeDuration(context: Context): Int {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_SNOOZE_MINUTES, DEFAULT_SNOOZE_MINUTES)
    }

    // ── Cancel daily alarm ───────────────────────────────────────────────

    fun cancel(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TtsAlarmReceiver::class.java).apply {
            action = "com.medivault.TTS_ALARM_$id"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        cancelFollowUp(context, id)
        Log.d(TAG, "Cancelled TTS alarm #$id")
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun buildIntent(context: Context, id: Int, name: String, hour: Int, minute: Int): Intent {
        return Intent(context, TtsAlarmReceiver::class.java).apply {
            action = "com.medivault.TTS_ALARM_$id"
            putExtra(TtsAlarmReceiver.EXTRA_MEDICINE_NAME, name)
            putExtra(TtsAlarmReceiver.EXTRA_HOUR, hour)
            putExtra(TtsAlarmReceiver.EXTRA_MINUTE, minute)
            putExtra(TtsAlarmReceiver.EXTRA_REMINDER_ID, id)
        }
    }
}
