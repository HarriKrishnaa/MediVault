import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../shared/theme/app_colors.dart';

/// Detailed adherence view for a single medication reminder.
/// Shows overall stats, a progress indicator, and daily log history.
class AdherenceScreen extends StatefulWidget {
  final int reminderId;
  final String medicineName;
  final int durationDays;
  final String startDate;

  const AdherenceScreen({
    Key? key,
    required this.reminderId,
    required this.medicineName,
    required this.durationDays,
    required this.startDate,
  }) : super(key: key);

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  Map<String, int> _stats = {'taken': 0, 'not_now': 0, 'total_days': 0};
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await DatabaseHelper.instance.getAdherenceStats(
      widget.reminderId,
    );
    final logs = await DatabaseHelper.instance.getAdherenceLogs(
      widget.reminderId,
    );
    if (mounted) {
      setState(() {
        _stats = stats;
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  int get _elapsedDays {
    final start = DateTime.tryParse(widget.startDate);
    if (start == null) return 0;
    return DateTime.now().difference(start).inDays + 1;
  }

  double get _adherencePercent {
    final days = _elapsedDays;
    if (days <= 0) return 0;
    return ((_stats['taken'] ?? 0) / days * 100).clamp(0, 100);
  }

  Color get _adherenceColor {
    final pct = _adherencePercent;
    if (pct >= 80) return AppColors.success;
    if (pct >= 50) return Colors.orange;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicineName),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  _buildProgressCard(),
                  const SizedBox(height: 20),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final taken = _stats['taken'] ?? 0;
    final notNow = _stats['not_now'] ?? 0;
    final elapsed = _elapsedDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_adherenceColor, _adherenceColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _adherenceColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_adherencePercent.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Adherence Rate',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatPill('✅ Taken', '$taken days', Colors.white),
              _buildStatPill('❌ Skipped', '$notNow days', Colors.white),
              _buildStatPill('📅 Elapsed', '$elapsed days', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final taken = _stats['taken'] ?? 0;
    final total = widget.durationDays;
    final progress = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course Progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
              ),
              Text(
                '$taken / $total days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _adherenceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_adherenceColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% of course completed',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No history yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Actions will appear here when you respond to reminders',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF303030),
            ),
          ),
        ),
        ..._logs.map(_buildLogTile),
      ],
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final isTaken = action == 'taken';
    final actionTime = DateTime.tryParse(log['action_time'] as String);
    final dateStr = log['action_date'] as String;

    final timeStr = actionTime != null
        ? '${actionTime.hour > 12
              ? actionTime.hour - 12
              : actionTime.hour == 0
              ? 12
              : actionTime.hour}:${actionTime.minute.toString().padLeft(2, '0')} ${actionTime.hour >= 12 ? 'PM' : 'AM'}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTaken
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTaken ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isTaken ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTaken ? 'Taken' : 'Skipped',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isTaken ? AppColors.success : AppColors.error,
                  ),
                ),
                Text(
                  '$dateStr  •  $timeStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
