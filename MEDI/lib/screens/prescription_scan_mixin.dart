import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/prescription_scan_service.dart';
import '../services/prescription_parser_service.dart';
import 'prescription_confirm_sheet.dart';
import '../shared/theme/app_colors.dart';

/// Mix this into any [StatefulWidget] that needs to trigger a prescription scan.
///
/// Usage:
///   class _MyScreenState extends State<MyScreen>
///       with PrescriptionScanMixin {
///     // Call:  scanPrescription(context, onRemindersCreated: _loadReminders);
///   }
mixin PrescriptionScanMixin<T extends StatefulWidget> on State<T> {
  bool _scanning = false;

  bool get isScanning => _scanning;

  // ── Public entry-point ───────────────────────────────────────────

  /// Opens an image source chooser, runs OCR + parse, shows the confirm sheet,
  /// then saves reminders. Calls [onRemindersCreated] on success.
  Future<void> scanPrescription(
    BuildContext context, {
    required VoidCallback onRemindersCreated,
  }) async {
    // 1. Pick image source
    final source = await _pickImageSource(context);
    if (source == null) return;

    // 2. Get image
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (picked == null) return;

    // 3. Run OCR + Parse (show loading)
    _setScanning(true);
    late final PrescriptionScanResult result;
    try {
      final rawText = await PrescriptionScanService.instance.extractText(
        picked.path,
      );
      final parsedData = PrescriptionScanService.instance.parseText(rawText);
      result = PrescriptionScanResult(
        parsedData: parsedData,
        createdReminderIds: const [],
        rawOcrText: rawText,
      );
    } on PrescriptionScanException catch (e) {
      _setScanning(false);
      if (mounted) _showError(context, e.message);
      return;
    } catch (e) {
      _setScanning(false);
      if (mounted) _showError(context, 'Scan failed. Please try again.');
      return;
    } finally {
      _setScanning(false);
    }

    if (!mounted) return;

    // 4. Show confirmation sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrescriptionConfirmSheet(
        parsedData: result.parsedData,
        onConfirmed: () => Navigator.pop(context, true),
        onCancelled: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 5. Save reminders + schedule notifications
    _setScanning(true);
    try {
      await PrescriptionScanService.instance.saveReminders(result.parsedData);
      onRemindersCreated();
      if (mounted) _showSuccess(context, result.parsedData);
    } on PrescriptionScanException catch (e) {
      if (mounted) _showError(context, e.message);
    } catch (e) {
      if (mounted) _showError(context, 'Failed to save reminders.');
    } finally {
      _setScanning(false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  void _setScanning(bool value) {
    if (mounted) setState(() => _scanning = value);
  }

  Future<ImageSource?> _pickImageSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Scan Prescription',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how to add your prescription',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              color: AppColors.primary,
              label: 'Take a Photo',
              subtitle: 'Use your camera to capture the prescription',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF7E57C2),
              label: 'Choose from Gallery',
              subtitle: 'Select an existing prescription image',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(BuildContext context, ParsedPrescriptionData parsedData) {
    final count = parsedData.medicines.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              '✅ $count reminder${count == 1 ? '' : 's'} created successfully!',
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Private helper widget ────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
