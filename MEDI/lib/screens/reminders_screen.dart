import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_helper.dart';
import '../shared/services/notification_service.dart';
import '../shared/theme/app_colors.dart';
import 'adherence_screen.dart';
import 'scan_prescription_button.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  int _snoozeMinutes = 5;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _loadSnoozeDuration();
  }

  Future<void> _loadSnoozeDuration() async {
    final mins = await NotificationService.instance.getSnoozeDuration();
    if (mounted) setState(() => _snoozeMinutes = mins);
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Auto-deactivate expired reminders first.
      await DatabaseHelper.instance.deactivateExpiredReminders(userId);

      final data = await DatabaseHelper.instance.getActiveReminders(userId);
      if (mounted) {
        setState(() {
          _reminders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReminder(int id) async {
    await DatabaseHelper.instance.deleteReminder(id);
    await NotificationService.instance.cancelReminder(id);
    _loadReminders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder deleted'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Edit ────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(Map<String, dynamic> reminder) async {
    final id = reminder['id'] as int;
    final medicineName = reminder['medicine_name'] as String;
    final nameController = TextEditingController(text: medicineName);
    TimeOfDay selectedTime1 = TimeOfDay(
      hour: reminder['hour'] as int,
      minute: reminder['minute'] as int,
    );
    int durationDays = reminder['duration_days'] as int;
    String mealTiming = (reminder['meal_timing'] as String?) ?? 'any time';

    // Find sibling reminder (same medicine name, different id).
    Map<String, dynamic>? sibling;
    for (final r in _reminders) {
      if (r['id'] != id && r['medicine_name'] == medicineName) {
        sibling = r;
        break;
      }
    }

    bool hasSecondTiming = sibling != null;
    TimeOfDay selectedTime2 = sibling != null
        ? TimeOfDay(
            hour: sibling['hour'] as int,
            minute: sibling['minute'] as int,
          )
        : const TimeOfDay(hour: 21, minute: 0); // default 9 PM
    final int? siblingId = sibling?['id'] as int?;

    final mealOptions = ['before food', 'after food', 'any time'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Reminder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Medicine name
                  const Text(
                    'Medicine Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.medication_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      hintText: 'e.g. Paracetamol',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Timing 1 ──
                  const Text(
                    'Timing 1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTimePicker(
                    ctx: ctx,
                    time: selectedTime1,
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFFFA726),
                    onPicked: (picked) =>
                        setSheet(() => selectedTime1 = picked),
                  ),
                  const SizedBox(height: 16),

                  // ── Timing 2 toggle + picker ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Timing 2',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasSecondTiming ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasSecondTiming
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 28,
                            child: Switch(
                              value: hasSecondTiming,
                              activeColor: AppColors.primary,
                              onChanged: (val) =>
                                  setSheet(() => hasSecondTiming = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (hasSecondTiming) ...[
                    const SizedBox(height: 8),
                    _buildTimePicker(
                      ctx: ctx,
                      time: selectedTime2,
                      icon: Icons.nights_stay_rounded,
                      iconColor: const Color(0xFF7E57C2),
                      onPicked: (picked) =>
                          setSheet(() => selectedTime2 = picked),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Duration slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$durationDays days',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: durationDays.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    activeColor: AppColors.primary,
                    label: '$durationDays days',
                    onChanged: (v) => setSheet(() => durationDays = v.round()),
                  ),
                  const SizedBox(height: 12),

                  // Meal timing selector
                  const Text(
                    'Meal Timing',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: mealOptions.map((option) {
                      final isSelected = mealTiming == option;
                      final color = option == 'before food'
                          ? Colors.orange
                          : option == 'after food'
                          ? Colors.green
                          : Colors.grey.shade600;
                      final icon = option == 'before food'
                          ? Icons.no_meals_rounded
                          : option == 'after food'
                          ? Icons.restaurant_rounded
                          : Icons.access_time_filled_rounded;
                      final label = option == 'before food'
                          ? 'Before'
                          : option == 'after food'
                          ? 'After'
                          : 'Any time';

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheet(() => mealTiming = option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  icon,
                                  color: isSelected ? color : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected ? color : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a medicine name'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _saveEditWithDualTiming(
                          id: id,
                          medicineName: name,
                          hour1: selectedTime1.hour,
                          minute1: selectedTime1.minute,
                          hasSecondTiming: hasSecondTiming,
                          hour2: selectedTime2.hour,
                          minute2: selectedTime2.minute,
                          siblingId: siblingId,
                          durationDays: durationDays,
                          mealTiming: mealTiming,
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Changes'),
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
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable time-picker row widget used by the edit dialog.
  Widget _buildTimePicker({
    required BuildContext ctx,
    required TimeOfDay time,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: ctx,
          initialTime: time,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primary.withValues(alpha: 0.04),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(
              time.format(ctx),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEditWithDualTiming({
    required int id,
    required String medicineName,
    required int hour1,
    required int minute1,
    required bool hasSecondTiming,
    required int hour2,
    required int minute2,
    required int? siblingId,
    required int durationDays,
    required String mealTiming,
  }) async {
    // 1. Update the primary reminder.
    await DatabaseHelper.instance.updateReminder(
      id,
      medicineName: medicineName,
      hour: hour1,
      minute: minute1,
      durationDays: durationDays,
      mealTiming: mealTiming,
    );
    await NotificationService.instance.cancelReminder(id);
    await NotificationService.instance.scheduleMedicationReminder(
      id: id,
      medicineName: medicineName,
      hour: hour1,
      minute: minute1,
      durationDays: durationDays,
      mealTiming: mealTiming,
    );

    // 2. Handle the second timing.
    if (hasSecondTiming) {
      if (siblingId != null) {
        // Sibling already exists – update it.
        await DatabaseHelper.instance.updateReminder(
          siblingId,
          medicineName: medicineName,
          hour: hour2,
          minute: minute2,
          durationDays: durationDays,
          mealTiming: mealTiming,
        );
        await NotificationService.instance.cancelReminder(siblingId);
        await NotificationService.instance.scheduleMedicationReminder(
          id: siblingId,
          medicineName: medicineName,
          hour: hour2,
          minute: minute2,
          durationDays: durationDays,
          mealTiming: mealTiming,
        );
      } else {
        // No sibling yet – create a new reminder row for timing 2.
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final newId = await DatabaseHelper.instance.insertReminder({
            'user_id': userId,
            'medicine_name': medicineName,
            'hour': hour2,
            'minute': minute2,
            'duration_days': durationDays,
            'start_date': DateTime.now().toIso8601String(),
            'is_active': 1,
            'meal_timing': mealTiming,
          });
          await NotificationService.instance.scheduleMedicationReminder(
            id: newId,
            medicineName: medicineName,
            hour: hour2,
            minute: minute2,
            durationDays: durationDays,
            mealTiming: mealTiming,
          );
        }
      }
    } else if (siblingId != null) {
      // User turned OFF the second timing – delete the sibling.
      await DatabaseHelper.instance.deleteReminder(siblingId);
      await NotificationService.instance.cancelReminder(siblingId);
    }

    _loadReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reminder updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final displayMin = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMin $period';
  }

  String _remainingDays(Map<String, dynamic> r) {
    final start = DateTime.tryParse(r['start_date'] as String);
    final duration = r['duration_days'] as int;
    if (start == null) return '$duration days';
    final end = start.add(Duration(days: duration));
    final remaining = end.difference(DateTime.now()).inDays;
    return remaining > 0 ? '$remaining days left' : 'Ending today';
  }

  IconData _timeIcon(int hour) {
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.nights_stay_rounded;
  }

  Color _timeColor(int hour) {
    if (hour < 12) return const Color(0xFFFFA726); // morning orange
    if (hour < 17) return const Color(0xFF42A5F5); // afternoon blue
    return const Color(0xFF7E57C2); // night purple
  }

  String _getTimePeriod(int hour) {
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 20) return 'Evening';
    return 'Night';
  }

  Widget _buildMealTimingBadge(String mealTiming) {
    final isBeforeFood = mealTiming == 'before food';
    final isAfterFood = mealTiming == 'after food';
    final color = isBeforeFood
        ? Colors.orange
        : isAfterFood
        ? Colors.green
        : Colors.grey.shade400;
    final icon = isBeforeFood
        ? Icons.no_meals_rounded
        : isAfterFood
        ? Icons.restaurant_rounded
        : Icons.access_time_filled_rounded;
    final label = isBeforeFood
        ? 'Before food'
        : isAfterFood
        ? 'After food'
        : 'Any time';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReminders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _reminders.isEmpty
          ? _buildEmptyState()
          : _buildReminderList(),
      floatingActionButton: _reminders.isNotEmpty
          ? ScanPrescriptionButton(
              onRemindersCreated: _loadReminders,
              compact: true,
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.alarm_off_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No active reminders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a prescription to automatically\ncreate medication reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ScanPrescriptionButton(onRemindersCreated: _loadReminders),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderList() {
    // Group reminders by time-of-day bucket.
    final morning = _reminders.where((r) => (r['hour'] as int) < 12).toList();
    final afternoon = _reminders
        .where((r) => (r['hour'] as int) >= 12 && (r['hour'] as int) < 17)
        .toList();
    final night = _reminders.where((r) => (r['hour'] as int) >= 17).toList();

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Summary header
          _buildSummaryCard(),
          const SizedBox(height: 12),
          _buildSnoozeDurationSelector(),
          const SizedBox(height: 20),
          if (morning.isNotEmpty) ...[
            _buildSectionHeader(
              'Morning',
              Icons.wb_sunny_rounded,
              const Color(0xFFFFA726),
            ),
            ...morning.map(_buildReminderCard),
            const SizedBox(height: 16),
          ],
          if (afternoon.isNotEmpty) ...[
            _buildSectionHeader(
              'Afternoon',
              Icons.wb_cloudy_rounded,
              const Color(0xFF42A5F5),
            ),
            ...afternoon.map(_buildReminderCard),
            const SizedBox(height: 16),
          ],
          if (night.isNotEmpty) ...[
            _buildSectionHeader(
              'Night',
              Icons.nights_stay_rounded,
              const Color(0xFF7E57C2),
            ),
            ...night.map(_buildReminderCard),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSnoozeDurationSelector() {
    const options = [5, 10, 15, 30];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.snooze_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Remind Later',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
          ),
          ...options.map((min) {
            final isSelected = min == _snoozeMinutes;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await NotificationService.instance.setSnoozeDuration(min);
                  setState(() => _snoozeMinutes = min);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${min}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF757575),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final uniqueMeds = _reminders.map((r) => r['medicine_name']).toSet().length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Medications',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$uniqueMeds medicine${uniqueMeds == 1 ? '' : 's'} · ${_reminders.length} dose${_reminders.length == 1 ? '' : 's'}/day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> r) {
    final hour = r['hour'] as int;
    final minute = r['minute'] as int;
    final color = _timeColor(hour);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Dismissible(
        key: ValueKey(r['id']),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => _deleteReminder(r['id'] as int),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_timeIcon(hour), color: color, size: 24),
          ),
          title: Text(
            r['medicine_name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              const SizedBox(height: 2),
              // Time Row
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${_formatTime(hour, minute)} (${_getTimePeriod(hour)})',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Remaining Row
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Remaining: ${_remainingDays(r)} days',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildMealTimingBadge(r['meal_timing'] as String? ?? 'any time'),
              const SizedBox(height: 4),
              // Adherence badge
              FutureBuilder<Map<String, int>>(
                future: DatabaseHelper.instance.getAdherenceStats(
                  r['id'] as int,
                ),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final taken = snap.data!['taken'] ?? 0;
                  final totalDays = snap.data!['total_days'] ?? 0;
                  if (totalDays == 0) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$taken/$totalDays days taken',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          // ── Edit + Delete buttons ─────────────────────────
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.analytics_outlined, size: 20),
                color: Colors.blueGrey,
                tooltip: 'Adherence',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdherenceScreen(
                      reminderId: r['id'] as int,
                      medicineName: r['medicine_name'] as String,
                      durationDays: r['duration_days'] as int,
                      startDate: r['start_date'] as String,
                    ),
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: AppColors.primary,
                tooltip: 'Edit',
                onPressed: () => _showEditDialog(r),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.grey.shade400,
                tooltip: 'Delete',
                onPressed: () => _showDeleteConfirmation(r['id'] as int),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: const Text(
          'This medication reminder will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReminder(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
