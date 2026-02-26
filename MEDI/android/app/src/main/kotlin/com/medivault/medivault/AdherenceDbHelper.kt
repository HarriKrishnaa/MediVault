package com.medivault.medivault

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Native SQLite helper that writes adherence logs directly into the same
 * `medivault.db` used by Flutter's sqflite.  This lets the
 * NotificationActionReceiver persist Taken / Not Now actions even when
 * the Flutter engine is not running.
 */
class AdherenceDbHelper(context: Context) : SQLiteOpenHelper(
    context,
    context.getDatabasePath("medivault.db").absolutePath,
    null,
    4   // must match Flutter's DB version
) {

    companion object {
        const val TAG = "AdherenceDb"
        const val TABLE = "adherence_log"
    }

    override fun onCreate(db: SQLiteDatabase) {
        // Table creation is handled by Flutter; this is only for cases
        // where native code opens the DB before Flutter does.
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS $TABLE (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reminder_id INTEGER NOT NULL,
                medicine_name TEXT NOT NULL,
                action TEXT NOT NULL,
                action_date TEXT NOT NULL,
                action_time TEXT NOT NULL
            )
        """)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Let Flutter handle migrations; just ensure the table exists.
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS $TABLE (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reminder_id INTEGER NOT NULL,
                medicine_name TEXT NOT NULL,
                action TEXT NOT NULL,
                action_date TEXT NOT NULL,
                action_time TEXT NOT NULL
            )
        """)
    }

    /**
     * Log a Taken or Not Now action.
     * @param reminderId  the medication_reminders.id
     * @param medicineName  e.g. "Paracetamol"
     * @param action  "taken" or "not_now"
     */
    fun logAction(reminderId: Int, medicineName: String, action: String) {
        try {
            val now = Date()
            val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val timeFmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

            val values = ContentValues().apply {
                put("reminder_id", reminderId)
                put("medicine_name", medicineName)
                put("action", action)
                put("action_date", dateFmt.format(now))
                put("action_time", timeFmt.format(now))
            }

            val db = writableDatabase
            val rowId = db.insert(TABLE, null, values)
            Log.d(TAG, "Logged adherence: $action for #$reminderId ($medicineName) → row $rowId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log adherence: ${e.message}")
        }
    }
}
