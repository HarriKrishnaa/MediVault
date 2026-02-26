import 'package:flutter/material.dart';
import 'prescription_scan_mixin.dart';
import '../shared/theme/app_colors.dart';

/// A ready-to-use scan button + loading overlay.
/// Drop this anywhere that needs a "Scan Prescription" button.
///
/// Example:
///   ScanPrescriptionButton(onRemindersCreated: _loadReminders)
class ScanPrescriptionButton extends StatefulWidget {
  final VoidCallback onRemindersCreated;
  final bool compact; // true → FAB-style, false → full-width button

  const ScanPrescriptionButton({
    Key? key,
    required this.onRemindersCreated,
    this.compact = false,
  }) : super(key: key);

  @override
  State<ScanPrescriptionButton> createState() => _ScanPrescriptionButtonState();
}

class _ScanPrescriptionButtonState extends State<ScanPrescriptionButton>
    with PrescriptionScanMixin {
  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return FloatingActionButton.extended(
        onPressed: isScanning
            ? null
            : () => scanPrescription(
                context,
                onRemindersCreated: widget.onRemindersCreated,
              ),
        backgroundColor: AppColors.primary,
        icon: isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.document_scanner_rounded),
        label: Text(isScanning ? 'Scanning…' : 'Scan Prescription'),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isScanning
            ? null
            : () => scanPrescription(
                context,
                onRemindersCreated: widget.onRemindersCreated,
              ),
        icon: isScanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.document_scanner_rounded),
        label: Text(
          isScanning ? 'Scanning Prescription…' : 'Scan Prescription',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
