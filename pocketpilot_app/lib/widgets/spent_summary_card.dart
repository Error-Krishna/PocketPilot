import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpentSummaryCard extends StatelessWidget {
  final double spentThisMonth;
  final double monthlyBudget;
  final int remainingDays;

  const SpentSummaryCard({
    super.key,
    required this.spentThisMonth,
    required this.monthlyBudget,
    required this.remainingDays,
  });

  @override
  Widget build(BuildContext context) {
    final percent = monthlyBudget > 0
        ? (spentThisMonth / monthlyBudget).clamp(0.0, 1.0)
        : 0.0;
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      color: const Color(0xFFF97316).withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spent This Month',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.trending_down,
                    size: 24, color: Color(0xFFF97316)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(spentThisMonth),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade800,
              color: const Color(0xFFF97316),
            ),
            const SizedBox(height: 8),
            Text(
              'of ${currency.format(monthlyBudget)} monthly plan '
              '· $remainingDays day${remainingDays == 1 ? '' : 's'} left',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
