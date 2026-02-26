import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static final SessionManager instance = SessionManager._init();

  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  bool _isLocked = false;
  int _timeoutMinutes = 5; // Default 5 minutes

  final StreamController<bool> _lockStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get lockStateStream => _lockStateController.stream;

  SessionManager._init();

  // Initialize session manager
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _timeoutMinutes = prefs.getInt('session_timeout_minutes') ?? 5;

    // Always start unlocked on app launch — lock is only for active sessions
    _isLocked = false;
    await prefs.setBool('session_locked', false);

    startTracking();
  }

  // Start tracking user activity
  void startTracking() {
    _lastActivityTime = DateTime.now();
    _resetTimer();
  }

  // Stop tracking (on logout)
  void stopTracking() {
    _inactivityTimer?.cancel();
    _lastActivityTime = null;
  }

  // Record user activity
  void recordActivity() {
    if (_isLocked) return;

    _lastActivityTime = DateTime.now();
    _resetTimer();
  }

  // Reset inactivity timer
  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), _onTimeout);
  }

  // Handle timeout
  void _onTimeout() {
    lockSession();
  }

  // Lock the session
  Future<void> lockSession() async {
    _isLocked = true;
    _inactivityTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_locked', true);

    _lockStateController.add(true);
  }

  // Unlock the session
  Future<void> unlockSession() async {
    _isLocked = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_locked', false);

    startTracking();
    _lockStateController.add(false);
  }

  // Check if session is locked
  bool get isLocked => _isLocked;

  // Get timeout duration in minutes
  int get timeoutMinutes => _timeoutMinutes;

  // Set timeout duration
  Future<void> setTimeoutMinutes(int minutes) async {
    _timeoutMinutes = minutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_timeout_minutes', minutes);

    if (!_isLocked) {
      _resetTimer();
    }
  }

  // Get time since last activity
  Duration? getTimeSinceLastActivity() {
    if (_lastActivityTime == null) return null;
    return DateTime.now().difference(_lastActivityTime!);
  }

  // Get time until timeout
  Duration? getTimeUntilTimeout() {
    if (_lastActivityTime == null) return null;
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    final timeout = Duration(minutes: _timeoutMinutes);
    return timeout - elapsed;
  }

  // Dispose
  void dispose() {
    _inactivityTimer?.cancel();
    _lockStateController.close();
  }
}
