import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../services/database_helper.dart';
import 'tts_service.dart';

// Top-level background handler for notification action buttons.
// Must be top-level (not a class method) and annotated for AOT.
@pragma('vm:entry-point')
void _onBackgroundNotificationAction(NotificationResponse response) {
  debugPrint(
    'BG Notification action: id=${response.actionId}, payload=${response.payload}',
  );
  // When the app is in the background, the MethodChannel is not available.
  // The action buttons use cancelNotification: true, so the notification
  // is dismissed.  The native NotificationActionReceiver handles the
  // TTS acknowledgement natively, so no Dart-side work is needed here.
}

/// Handles scheduling / cancelling local push notifications for medication
/// reminders.  Uses [FlutterLocalNotificationsPlugin] under the hood.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // MethodChannel for native Android TTS alarms.
  static const _ttsChannel = MethodChannel('com.medivault.medivault/tts_alarm');

  // ── Initialisation ──────────────────────────────────────────────────

  /// Must be called once during app startup (before `runApp`).
  Future<void> init() async {
    if (_initialised) return;

    // Timezone data is required for zonedSchedule.
    tz.initializeTimeZones();

    // Use the device's local timezone name when available, falling back to
    // offset-based detection.
    _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    final didInit = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationAction,
    );

    debugPrint(
      'NotificationService.init() → plugin.initialize returned: $didInit',
    );

    // Create / update the notification channel explicitly so that any
    // cached channel from previous installs is refreshed.
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            'medivault_reminders',
            'Medication Reminders',
            description: 'Daily medication reminder alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
        debugPrint('Notification channel created / updated');
      }
    }

    _initialised = true;
    debugPrint('NotificationService initialised ✔');
  }

  /// Configure the timezone library to use the device-local zone.
  void _configureLocalTimezone() {
    try {
      final now = DateTime.now();
      final offsetInMs = now.timeZoneOffset.inMilliseconds;

      // Try matching by timezone name first (more reliable).
      final tzName = now.timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(tzName)) {
        tz.setLocalLocation(tz.getLocation(tzName));
        debugPrint('Timezone set via name: $tzName');
        return;
      }

      // Fall back to matching by UTC offset.
      final locationName = tz.timeZoneDatabase.locations.keys.firstWhere((key) {
        final loc = tz.getLocation(key);
        return loc.currentTimeZone.offset == offsetInMs;
      }, orElse: () => 'UTC');
      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint('Timezone set via offset ($offsetInMs ms): $locationName');
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('Timezone fallback to UTC: $e');
    }
  }

  /// Callback when the user taps a notification or an action button.
  void _onNotificationTap(NotificationResponse response) {
    debugPrint(
      'Notification response: action=${response.actionId}, payload=${response.payload}',
    );
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final id = data['id'] as int? ?? -1;
      final name = data['name'] as String? ?? 'your medicine';
      final hour = data['hour'] as int? ?? 0;
      final minute = data['minute'] as int? ?? 0;
      final actionId = response.actionId ?? '';

      if (actionId == 'taken' || actionId == 'not_willing') {
        // User acknowledged — stop TTS repeats via native channel.
        if (Platform.isAndroid && id >= 0) {
          _ttsChannel.invokeMethod('acknowledgeTtsAlarm', {'id': id});
        }
        // Log adherence (backup: native NotificationActionReceiver also logs).
        final dbAction = actionId == 'taken' ? 'taken' : 'not_now';
        DatabaseHelper.instance.logAdherenceAction(
          reminderId: id,
          medicineName: name,
          action: dbAction,
        );
        debugPrint('Alarm #$id acknowledged & logged ($actionId)');
      } else if (actionId == 'remind_later') {
        // Follow-up already scheduled by native TtsAlarmReceiver.
        debugPrint('Alarm #$id will re-fire in 5 min');
      } else {
        // Plain notification tap → speak the medication name.
        TtsService.instance.speakMedicationNotification(
          medicineName: name,
          hour: hour,
          minute: minute,
        );
      }
    } catch (e) {
      debugPrint('Failed to parse notification payload: $e');
    }
  }

  // ── Permission ──────────────────────────────────────────────────────

  /// Request all notification-related permissions for Android 13+ / 14+ / 15.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;

    // 1. POST_NOTIFICATIONS (Android 13+)
    bool notifGranted = false;
    try {
      notifGranted = await android.requestNotificationsPermission() ?? false;
      debugPrint('POST_NOTIFICATIONS permission: $notifGranted');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // 2. SCHEDULE_EXACT_ALARM (Android 14+ / 15)
    try {
      final exactGranted = await android.requestExactAlarmsPermission();
      debugPrint('SCHEDULE_EXACT_ALARM permission: $exactGranted');
    } catch (e) {
      // May throw on devices/APIs that don't support this — safe to ignore.
      debugPrint(
        'Exact alarm permission request failed (expected on older API): $e',
      );
    }

    return notifGranted;
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Schedule a daily medication reminder via native Android TTS alarm.
  ///
  /// The native [TtsAlarmReceiver] handles EVERYTHING:
  ///   1. Speaks tablet name + time via Android TTS
  ///   2. Shows persistent notification with action buttons
  ///   3. Schedules auto follow-up repeats until user responds
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicineName,
    required int hour,
    required int minute,
    int durationDays = 5,
    String mealTiming = 'any time',
  }) async {
    if (!_initialised) await init();

    if (Platform.isAndroid) {
      try {
        await _ttsChannel.invokeMethod('scheduleTtsAlarm', {
          'id': id,
          'name': medicineName,
          'hour': hour,
          'minute': minute,
        });
        debugPrint(
          '✅ TTS alarm scheduled for #$id "$medicineName" '
          'at $hour:${minute.toString().padLeft(2, '0')}',
        );
      } catch (e) {
        debugPrint('⚠️ TTS alarm scheduling failed: $e');
      }
    }
  }

  // ── Immediate notification (for testing) ────────────────────────────

  /// Fire a notification right now. Useful to verify the notification
  /// pipeline is working end-to-end.
  Future<void> showTestNotification() async {
    if (!_initialised) await init();

    const androidDetails = AndroidNotificationDetails(
      'medivault_reminders',
      'Medication Reminders',
      channelDescription: 'Daily medication reminder alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      99999, // unique test id
      '💊 Test Notification',
      'If you see this, notifications are working!',
      details,
      payload: 'test',
    );
    debugPrint('🔔 Test notification fired');
  }

  // ── Cancellation ────────────────────────────────────────────────────

  /// Cancel a single scheduled notification and its TTS alarm by [id].
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    // Also cancel the native TTS alarm.
    if (Platform.isAndroid) {
      try {
        await _ttsChannel.invokeMethod('cancelTtsAlarm', {'id': id});
      } catch (_) {}
    }
    debugPrint('Cancelled notification + TTS alarm #$id');
  }

  /// Cancel every scheduled notification.
  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
    debugPrint('Cancelled all notifications');
  }

  // ── Snooze duration ─────────────────────────────────────────────────

  /// Set how many minutes "Remind Later" waits before re-firing.
  Future<void> setSnoozeDuration(int minutes) async {
    if (Platform.isAndroid) {
      await _ttsChannel.invokeMethod('setSnoozeDuration', {'minutes': minutes});
    }
    debugPrint('Snooze duration set to $minutes min');
  }

  /// Get the current snooze duration in minutes.
  Future<int> getSnoozeDuration() async {
    if (Platform.isAndroid) {
      final result = await _ttsChannel.invokeMethod<int>('getSnoozeDuration');
      return result ?? 5;
    }
    return 5;
  }

  // ── Diagnostics ─────────────────────────────────────────────────────

  /// Return a list of all pending (scheduled) notification requests.
  /// Useful for debugging whether notifications are actually scheduled.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  // ── Re-scheduling (app restart / reboot) ────────────────────────────

  /// Query all active reminders from the local database and re-schedule
  /// their notifications.  Call this on every app startup so that
  /// notifications survive app restarts and device reboots.
  Future<void> rescheduleAllActiveReminders(String? userId) async {
    if (userId == null) return;

    final reminders = await DatabaseHelper.instance.getActiveReminders(userId);

    // Cancel stale notifications first.
    await cancelAllReminders();

    for (final r in reminders) {
      await scheduleMedicationReminder(
        id: r['id'] as int,
        medicineName: r['medicine_name'] as String,
        hour: r['hour'] as int,
        minute: r['minute'] as int,
        durationDays: r['duration_days'] as int,
        mealTiming: (r['meal_timing'] as String?) ?? 'any time',
      );
    }

    // Log pending notifications for diagnostics.
    final pending = await getPendingNotifications();
    debugPrint(
      '📋 Re-scheduled ${reminders.length} reminder(s). '
      'Pending notifications: ${pending.length}',
    );
    for (final p in pending) {
      debugPrint('  → #${p.id}: ${p.title}');
    }
  }
}
