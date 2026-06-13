import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

Color _withOpacity(Color c, double opacity) =>
    // ignore: deprecated_member_use
    Color.fromARGB((opacity * 255).round(), c.red, c.green, c.blue);

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color textColor;
    if (s.contains('accepted') ||
        s.contains('approved') ||
        s.contains('approuv') ||
        s.contains('valid')) {
      bg = _withOpacity(AppColors.success, 0.12);
      textColor = AppColors.success;
    } else if (s.contains('rejected') || s.contains('refus')) {
      bg = _withOpacity(AppColors.error, 0.12);
      textColor = AppColors.error;
    } else {
      bg = _withOpacity(AppColors.pending, 0.12);
      textColor = AppColors.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }
}
