import 'package:flutter/material.dart';
import '../models/monthly_archive.dart';

/// Small glance at the most recently completed cycle. Tap to see full
/// month-by-month history.
class LastCycleCard extends StatelessWidget {
  final MonthlyArchive? lastCycle;
  final VoidCallback? onTap;

  const LastCycleCard({super.key, this.lastCycle, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (lastCycle == null) {
      return const SizedBox.shrink();
    }

    final saved = lastCycle!.totalSaved;
    final isPositive = saved >= 0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPositive
                        ? 'Last cycle: saved ₹${saved.toStringAsFixed(0)}'
                        : 'Last cycle: overspent ₹${(-saved).toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
