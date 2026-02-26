import 'package:flutter/material.dart';

/// Structured data for a single parsed medicine from a prescription.
class ParsedMedicineData {
  final String name;
  final List<TimeOfDay> times;
  final int durationDays;

  /// 'before food' | 'after food' | 'any time'
  final String mealTiming;

  const ParsedMedicineData({
    required this.name,
    required this.times,
    required this.durationDays,
    this.mealTiming = 'any time',
  });

  @override
  String toString() =>
      'ParsedMedicineData(name: $name, times: $times, days: $durationDays, meal: $mealTiming)';
}

/// Structured data for the full parsed prescription.
class ParsedPrescriptionData {
  final DateTime? writtenDate;
  final List<ParsedMedicineData> medicines;

  const ParsedPrescriptionData({
    required this.writtenDate,
    required this.medicines,
  });

  /// Convenience: list of all medicine names.
  List<String> get medicationNames =>
      medicines.map((item) => item.name).toList(growable: false);

  /// Convenience: times of the first medicine (backward-compat).
  List<TimeOfDay> get times =>
      medicines.isNotEmpty ? medicines.first.times : const <TimeOfDay>[];

  /// Convenience: duration of the first medicine.
  int? get durationDays =>
      medicines.isNotEmpty ? medicines.first.durationDays : null;

  /// Default: every day of the week.
  List<int> get daysOfWeek => const [1, 2, 3, 4, 5, 6, 7];
}

/// Parses raw OCR text from a prescription into structured medication data.
class PrescriptionParserService {
  static ParsedPrescriptionData parse(String text) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    final medicines = <ParsedMedicineData>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || !_isMedicationLine(line)) continue;

      final name = _cleanMedicineName(line);
      int? duration;
      List<TimeOfDay> times = [];
      String mealTiming = 'any time';

      // Combine the medication line and the next 5 lines to search for cues.
      final lookAheadLines = <String>[line.toLowerCase()];
      for (int j = i + 1; j < i + 6 && j < lines.length; j++) {
        lookAheadLines.add(lines[j].trim().toLowerCase());
      }
      final combinedText = lookAheadLines.join(' ');

      // Extract duration from combined text.
      for (final chunk in lookAheadLines) {
        duration ??= _extractDurationDays(chunk);
      }

      // Check for explicit am/pm times first.
      for (final chunk in lookAheadLines) {
        final explicitTimes = _extractExplicitTimes(chunk);
        if (explicitTimes.isNotEmpty) {
          times.addAll(explicitTimes); // Collect ALL explicit times
        }
      }

      // Determine meal timing.
      if (combinedText.contains('before food') ||
          combinedText.contains('before meal')) {
        mealTiming = 'before food';
      } else if (combinedText.contains('after food') ||
          combinedText.contains('after meal')) {
        mealTiming = 'after food';
      }

      // Build times from keyword-based morning / afternoon / night cues
      // if no explicit times were found (or to supplement them).
      if (times.isEmpty) {
        times = _buildTimesFromKeywords(combinedText, mealTiming);
      }

      // Final fallback: dosage abbreviation count → spread across default slots.
      if (times.isEmpty) {
        int? doses;
        for (final chunk in lookAheadLines) {
          doses ??= _extractDosesPerDay(chunk);
        }
        if (doses != null) {
          times = mealTiming == 'before food'
              ? _buildBeforeFoodTimes(doses)
              : mealTiming == 'after food'
              ? _buildAfterFoodTimes(doses)
              : _buildDefaultTimes(doses);
        }
      }

      // If still empty, default to 9 AM
      if (times.isEmpty) {
        times = const [TimeOfDay(hour: 9, minute: 0)];
      }

      // Deduplicate times
      final uniqueTimes = <String>{};
      final dedupedTimes = <TimeOfDay>[];
      for (final t in times) {
        final key = '${t.hour}:${t.minute}';
        if (uniqueTimes.add(key)) {
          dedupedTimes.add(t);
        }
      }
      times = dedupedTimes;

      medicines.add(
        ParsedMedicineData(
          name: name,
          times: times,
          durationDays: duration ?? 5,
          mealTiming: mealTiming,
        ),
      );
    }

    return ParsedPrescriptionData(
      writtenDate: DateTime.now(),
      medicines: medicines,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Detects lines containing medication form keywords.
  static bool _isMedicationLine(String line) {
    // Reject lines that contain "Tot" or "Total" (total count annotation)
    // This handles (Tot:8 Tab) or Total: 8
    if (RegExp(r'\b(tot|total)\b', caseSensitive: false).hasMatch(line)) {
      return false;
    }

    final forms = RegExp(
      r'\b(tab|tablet|cap|capsule|syr|syrup|inj|injection|drop|drops|ointment)\b',
      caseSensitive: false,
    );
    return forms.hasMatch(line);
  }

  /// Strips dosage-form prefix and leading numbering to get a clean medicine name.
  static String _cleanMedicineName(String line) {
    return line
        // Strip leading item numbers like "4) " or "1. " or "1 "
        .replaceAll(RegExp(r'^\d+[.)\s]+'), '')
        // Remove common dosage-form prefixes like "Tab.", "Cap.", etc.
        .replaceAll(
          RegExp(
            r'^(tab\.?|tablet|cap\.?|capsule|syr\.?|syrup|inj\.?|injection|drop|drops|ointment)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  /// Extracts duration in days, e.g. "5 days", "for 7 days", "1 week", "2 months".
  static int? _extractDurationDays(String text) {
    // Try "days" pattern
    final daysMatch = RegExp(r'(\d+)\s*days?').firstMatch(text);
    if (daysMatch != null) return int.tryParse(daysMatch.group(1)!);

    // Try "weeks" pattern (x7)
    final weeksMatch = RegExp(r'(\d+)\s*weeks?').firstMatch(text);
    if (weeksMatch != null) {
      final weeks = int.tryParse(weeksMatch.group(1)!);
      if (weeks != null) return weeks * 7;
    }

    // Try "months" pattern (x30 approx)
    final monthsMatch = RegExp(r'(\d+)\s*months?').firstMatch(text);
    if (monthsMatch != null) {
      final months = int.tryParse(monthsMatch.group(1)!);
      if (months != null) return months * 30;
    }

    return null;
  }

  /// Extracts the number of doses per day from abbreviations only (not keywords).
  static int? _extractDosesPerDay(String text) {
    if (RegExp(r'\bod\b').hasMatch(text)) return 1;
    if (RegExp(r'\bbid\b').hasMatch(text)) return 2;
    if (RegExp(r'\btds\b|\btid\b').hasMatch(text)) return 3;
    if (RegExp(r'\bqid\b').hasMatch(text)) return 4;

    final match = RegExp(
      r'(\d+)\s*(times?|x)\s*(a|per)?\s*day',
    ).firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);

    // Dosage patterns like "1-0-1", "1 - 0 - 1"
    final dosePattern = RegExp(
      r'^(\d)\s?-\s?(\d)\s?-\s?(\d)$',
    ).firstMatch(text.trim());
    if (dosePattern != null) {
      final total =
          int.parse(dosePattern.group(1)!) +
          int.parse(dosePattern.group(2)!) +
          int.parse(dosePattern.group(3)!);
      if (total > 0) return total;
    }

    return null;
  }

  /// Builds a list of [TimeOfDay] based on the presence of Keywords
  static List<TimeOfDay> _buildTimesFromKeywords(
    String text,
    String mealTiming,
  ) {
    // Keywords for morning
    // We include typo tolerance for OCR errors (moming, moring)
    final hasMorning =
        text.contains('morning') ||
        text.contains('moming') ||
        text.contains('moring') ||
        text.contains('mrng') ||
        RegExp(r'\b(morn|am)\b').hasMatch(text);

    // Keywords for afternoon
    final hasAfternoon =
        text.contains('afternoon') ||
        RegExp(r'\b(noon|lunch)\b').hasMatch(text);

    // Keywords for night
    // Include typo tolerance (nigh, nht, n1ght, nlght, niqht)
    final hasNight =
        text.contains('night') ||
        text.contains('evening') ||
        text.contains('bedtime') ||
        text.contains('dinner') ||
        text.contains('supper') ||
        text.contains('sleep') ||
        text.contains('nigh') || // often missed 't'
        text.contains('nht') ||
        text.contains('n1ght') ||
        text.contains('nlght') ||
        text.contains('niqht') ||
        RegExp(r'\b(nite|eve|pm|hs|qhs)\b').hasMatch(text);

    if (!hasMorning && !hasAfternoon && !hasNight) return [];

    // Adjust base hour by ±1 hour for before/after food.
    int morningHour = mealTiming == 'before food' ? 8 : 9; // 8 AM vs 9 AM
    int afternoonHour = mealTiming == 'before food' ? 12 : 13; // 12 PM vs 1 PM
    int nightHour = mealTiming == 'before food' ? 20 : 21; // 8 PM vs 9 PM

    final times = <TimeOfDay>[];
    if (hasMorning) times.add(TimeOfDay(hour: morningHour, minute: 0));
    if (hasAfternoon) times.add(TimeOfDay(hour: afternoonHour, minute: 0));
    if (hasNight) times.add(TimeOfDay(hour: nightHour, minute: 0));

    return times;
  }

  /// Parses explicit times like "8am", "9:30 pm".
  static List<TimeOfDay> _extractExplicitTimes(String text) {
    final matches = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)',
      caseSensitive: false,
    ).allMatches(text);

    final times = <TimeOfDay>[];
    for (final m in matches) {
      final hourRaw = int.parse(m.group(1)!);
      final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
      final period = m.group(3)!.toLowerCase();

      int hour = hourRaw;
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      times.add(TimeOfDay(hour: hour, minute: minute));
    }

    return times;
  }

  static List<TimeOfDay> _buildBeforeFoodTimes(int doses) {
    const base = [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 20, minute: 0),
    ];
    // Return first N doses
    // If doses > 3, we might need to distribute them more evenly, but taking first 3 is a safe default.
    return base.take(doses).toList();
  }

  static List<TimeOfDay> _buildAfterFoodTimes(int doses) {
    const base = [
      TimeOfDay(hour: 9, minute: 0),
      TimeOfDay(hour: 13, minute: 0),
      TimeOfDay(hour: 21, minute: 0),
    ];
    return base.take(doses).toList();
  }

  static List<TimeOfDay> _buildDefaultTimes(int doses) {
    return _buildBeforeFoodTimes(doses);
  }
}
