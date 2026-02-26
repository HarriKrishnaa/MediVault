import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Severity level of a diagnostic log entry.
enum DiagLevel { info, warning, error, fatal }

/// A single log entry produced by [DiagnosticsService].
class DiagEntry {
  final DateTime timestamp;
  final DiagLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  DiagEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    final lvl = level.name.toUpperCase().padRight(7);
    final st = stackTrace != null ? '\n  STACK: $stackTrace' : '';
    return '[$ts] $lvl [$tag] $message$st';
  }
}

/// Global diagnostics service.
///
/// Usage:
///   DiagnosticsService.log('MyTag', 'Something happened');
///   DiagnosticsService.error('MyTag', 'Boom', e, st);
///
/// Hook into Flutter error pipeline by calling [DiagnosticsService.install()]
/// before [runApp].
class DiagnosticsService {
  DiagnosticsService._();

  // ── In-memory ring buffer (keeps last 500 entries) ────────────────────
  static const int _maxEntries = 500;
  static final List<DiagEntry> _entries = [];
  static final StreamController<DiagEntry> _stream =
      StreamController.broadcast();

  /// Stream of new entries – useful for live log view.
  static Stream<DiagEntry> get stream => _stream.stream;

  /// All buffered entries (newest first).
  static List<DiagEntry> get entries => List.unmodifiable(_entries.reversed);

  // ── Log helpers ──────────────────────────────────────────────────────

  static void log(String tag, String message) =>
      _add(DiagLevel.info, tag, message);

  static void warn(String tag, String message) =>
      _add(DiagLevel.warning, tag, message);

  static void error(String tag, String message, [Object? err, StackTrace? st]) {
    final msg = err != null ? '$message\n  ERROR: $err' : message;
    _add(DiagLevel.error, tag, msg, st?.toString());
  }

  static void fatal(String tag, String message, [Object? err, StackTrace? st]) {
    final msg = err != null ? '$message\n  ERROR: $err' : message;
    _add(DiagLevel.fatal, tag, msg, st?.toString());
  }

  // ── Flutter / Dart hook ───────────────────────────────────────────────

  /// Call this BEFORE runApp to capture all unhandled errors.
  static void install() {
    // 1. Flutter framework errors (widget build failures, gesture errors, etc.)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      fatal(
        'FlutterError',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      // Still call the original handler so debug console stays intact
      originalOnError?.call(details);
    };

    // 2. Platform dispatcher errors (async errors escaping zone)
    PlatformDispatcher.instance.onError = (error, stack) {
      fatal('PlatformDispatcher', error.toString(), error, stack);
      return true; // mark handled
    };
  }

  // ── Clear / export ────────────────────────────────────────────────────

  static void clear() => _entries.clear();

  /// Writes the full log buffer to a .txt file in the app's temp dir.
  /// Returns the path of the written file.
  static Future<String> exportToFile() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/medivault_diag_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final content = _entries.reversed.map((e) => e.toString()).join('\n');
    await file.writeAsString(content);
    return file.path;
  }

  // ── Internal ──────────────────────────────────────────────────────────

  static void _add(
    DiagLevel level,
    String tag,
    String message, [
    String? stackTrace,
  ]) {
    final entry = DiagEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );

    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);

    _stream.add(entry);

    // Mirror to Flutter debug console
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }
}
