import 'package:flutter/material.dart';
import '../../services/enhanced_encryption_service.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = EnhancedEncryptionService.validatePasswordStrength(
      password,
    );

    Color color;
    String label;
    double percent;

    switch (strength.level) {
      case PasswordStrengthLevel.weak:
        color = Colors.red;
        label = 'Weak';
        percent = 0.33;
        break;
      case PasswordStrengthLevel.medium:
        color = Colors.orange;
        label = 'Medium';
        percent = 0.66;
        break;
      case PasswordStrengthLevel.strong:
        color = Colors.green;
        label = 'Strong';
        percent = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Stability: $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        if (strength.issues.isNotEmpty &&
            strength.level != PasswordStrengthLevel.strong) ...[
          const SizedBox(height: 8),
          ...strength.issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    issue,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
