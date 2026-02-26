import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/services/prescription_ocr_service.dart';
import 'prescription_parser_service.dart';
import 'database_helper.dart';
import '../shared/services/notification_service.dart';

/// Result returned after a full prescription scan + save.
class PrescriptionScanResult {
  final ParsedPrescriptionData parsedData;
  final List<int> createdReminderIds;
  final String rawOcrText;

  const PrescriptionScanResult({
    required this.parsedData,
    required this.createdReminderIds,
    required this.rawOcrText,
  });

  bool get hasReminders => createdReminderIds.isNotEmpty;
  int get totalDosesPerDay =>
      parsedData.medicines.fold(0, (sum, m) => sum + m.times.length);
}

/// Orchestrates the full prescription-to-reminder pipeline:
///   Image → OCR → Parse → Save to DB → Schedule Notifications
class PrescriptionScanService {
  PrescriptionScanService._();
  static final instance = PrescriptionScanService._();

  // ── Step 1: OCR ──────────────────────────────────────────────────

  /// Extracts text from a prescription image file.
  Future<String> extractText(String imagePath) async {
    final rawText = await PrescriptionOcrService.extractTextFromImagePath(
      imagePath,
    );
    if (rawText.trim().isEmpty) {
      throw const PrescriptionScanException(
        'No text could be extracted from the image. '
        'Please ensure the image is clear and well-lit.',
      );
    }
    return rawText;
  }

  // ── Step 2: Parse ────────────────────────────────────────────────

  /// Parses raw OCR text into structured prescription data.
  ParsedPrescriptionData parseText(String ocrText) {
    final parsed = PrescriptionParserService.parse(ocrText);
    if (parsed.medicines.isEmpty) {
      throw const PrescriptionScanException(
        'No medications were detected in the prescription. '
        'The image may be unclear or the format is not recognised.',
      );
    }
    return parsed;
  }

  // ── Step 3: Save + Schedule ──────────────────────────────────────

  /// Saves parsed medicines as reminders and schedules notifications.
  Future<List<int>> saveReminders(ParsedPrescriptionData data) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw const PrescriptionScanException(
        'You must be signed in to save reminders.',
      );
    }

    final createdIds = <int>[];
    final now = DateTime.now();

    for (final medicine in data.medicines) {
      for (final time in medicine.times) {
        final reminderId = await DatabaseHelper.instance.insertReminder({
          'user_id': userId,
          'medicine_name': medicine.name,
          'hour': time.hour,
          'minute': time.minute,
          'duration_days': medicine.durationDays,
          'start_date': now.toIso8601String(),
          'is_active': 1,
          'meal_timing': medicine.mealTiming,
        });

        await NotificationService.instance.scheduleMedicationReminder(
          id: reminderId,
          medicineName: medicine.name,
          hour: time.hour,
          minute: time.minute,
          durationDays: medicine.durationDays,
          mealTiming: medicine.mealTiming,
        );

        createdIds.add(reminderId);
      }
    }

    return createdIds;
  }

  // ── Full Pipeline ────────────────────────────────────────────────

  /// Runs the complete pipeline: OCR → Parse → Save → Schedule.
  /// Returns a [PrescriptionScanResult] on success.
  Future<PrescriptionScanResult> scanAndSave(String imagePath) async {
    final rawText = await extractText(imagePath);
    final parsedData = parseText(rawText);
    final ids = await saveReminders(parsedData);
    return PrescriptionScanResult(
      parsedData: parsedData,
      createdReminderIds: ids,
      rawOcrText: rawText,
    );
  }
}

class PrescriptionScanException implements Exception {
  final String message;
  const PrescriptionScanException(this.message);

  @override
  String toString() => message;
}
