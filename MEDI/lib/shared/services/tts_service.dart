import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS helper — speaks the medication name and scheduled time aloud.
///
/// Used as a fallback when notification is tapped (live speech).
/// The primary TTS mechanism is native Android [TtsAlarmReceiver] which
/// fires at the scheduled time automatically.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  // ── Initialisation ──────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // Prefer Google TTS engine on Android.
    final engines = await _tts.getEngines;
    if (engines is List) {
      final googleEngine = engines.firstWhere(
        (e) => e.toString().contains('google'),
        orElse: () => null,
      );
      if (googleEngine != null) {
        await _tts.setEngine(googleEngine.toString());
        debugPrint('TTS engine: $googleEngine');
      }
    }

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });

    _initialised = true;
    debugPrint('TtsService initialised ✔');
  }

  // ── Live speech (notification tap fallback) ─────────────────────────

  /// Speak the medication name and time aloud in real-time.
  /// Called when a notification is tapped as a fallback.
  Future<void> speakMedicationNotification({
    required String medicineName,
    required int hour,
    required int minute,
  }) async {
    if (!_initialised) await init();
    await stop();

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final displayMin = minute.toString().padLeft(2, '0');
    final timeStr = '$displayHour:$displayMin $period';

    final speech = 'Time to take $medicineName at $timeStr';
    debugPrint('TTS (live): $speech');
    await _tts.speak(speech);
  }

  // ── Stop ─────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}
