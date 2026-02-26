import 'package:flutter/material.dart';
import '../services/prescription_parser_service.dart';
import '../shared/theme/app_colors.dart';

/// Shows a confirmation sheet after OCR + parsing, before saving reminders.
/// Displays all detected medicines with their times, duration and meal timing.
/// The user can review and confirm (or cancel).
class PrescriptionConfirmSheet extends StatefulWidget {
  final ParsedPrescriptionData parsedData;
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;

  const PrescriptionConfirmSheet({
    Key? key,
    required this.parsedData,
    required this.onConfirmed,
    required this.onCancelled,
  }) : super(key: key);

  @override
  State<PrescriptionConfirmSheet> createState() =>
      _PrescriptionConfirmSheetState();
}

class _PrescriptionConfirmSheetState extends State<PrescriptionConfirmSheet> {
  @override
  Widget build(BuildContext context) {
    final medicines = widget.parsedData.medicines;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prescription Detected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${medicines.length} medicine${medicines.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Medicine cards
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: medicines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _MedicineCard(medicine: medicines[i]),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancelled,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: widget.onConfirmed,
                  icon: const Icon(Icons.alarm_add_rounded),
                  label: const Text('Set Reminders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final ParsedMedicineData medicine;

  const _MedicineCard({required this.medicine});

  String _formatTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour == 0
        ? 12
        : t.hour > 12
        ? t.hour - 12
        : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Color get _mealColor {
    if (medicine.mealTiming == 'before food') return Colors.orange;
    if (medicine.mealTiming == 'after food') return Colors.green;
    return Colors.grey.shade500;
  }

  IconData get _mealIcon {
    if (medicine.mealTiming == 'before food') return Icons.no_meals_rounded;
    if (medicine.mealTiming == 'after food') return Icons.restaurant_rounded;
    return Icons.access_time_filled_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine name + duration
          Row(
            children: [
              const Icon(
                Icons.medication_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${medicine.durationDays} days',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reminder times
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: medicine.times.map((t) {
              final hour = t.hour;
              final color = hour < 12
                  ? const Color(0xFFFFA726)
                  : hour < 17
                  ? const Color(0xFF42A5F5)
                  : const Color(0xFF7E57C2);
              final icon = hour < 12
                  ? Icons.wb_sunny_rounded
                  : hour < 17
                  ? Icons.wb_cloudy_rounded
                  : Icons.nights_stay_rounded;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(
                      _formatTime(t),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Meal timing badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_mealIcon, size: 13, color: _mealColor),
              const SizedBox(width: 5),
              Text(
                medicine.mealTiming[0].toUpperCase() +
                    medicine.mealTiming.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: _mealColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
