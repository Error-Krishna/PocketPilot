import 'package:flutter/material.dart';

/// Always-visible lifetime savings figure — the "big number" a student
/// should see at a glance without digging. Tap to drill into month-by-month
/// history.
class LifetimeSavingsCard extends StatelessWidget {
  final double lifetimeSavings;
  final VoidCallback? onTap;

  const LifetimeSavingsCard({
    super.key,
    required this.lifetimeSavings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Lifetime Savings',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${lifetimeSavings.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Icon(Icons.savings, size: 32, color: Color(0xFF22C55E)),
            ],
          ),
        ),
      ),
    );
  }
}
