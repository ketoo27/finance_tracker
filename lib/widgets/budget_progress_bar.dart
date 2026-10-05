import 'package:flutter/material.dart';
import '../core/theme.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.label,
    required this.spent,
    required this.target,
    this.color = AppColors.teal,
  });

  final String label;
  final double spent;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (spent / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - spent;
    final over = remaining < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              Text(
                '${formatRupee(spent)} / ${formatRupee(target)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 9,
              backgroundColor: AppColors.paperLine,
              valueColor: AlwaysStoppedAnimation(over ? AppColors.red : color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            over ? '${formatRupee(remaining)} over' : '${formatRupee(remaining)} left',
            style: TextStyle(fontSize: 11, color: over ? AppColors.red : AppColors.muted),
          ),
        ],
      ),
    );
  }
}
