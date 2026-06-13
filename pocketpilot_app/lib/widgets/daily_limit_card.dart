import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyLimitCard extends StatelessWidget {
  final double dailyLimit;
  final double savedToday;

  const DailyLimitCard({super.key, required this.dailyLimit, required this.savedToday});

  @override
  Widget build(BuildContext context) {
    final percent = dailyLimit > 0 ? (savedToday / dailyLimit).clamp(0.0, 1.0) : 0.0;
    return Card(
      color: const Color(0xFF38BDF8).withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today’s Safe Limit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(dailyLimit),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: percent, backgroundColor: Colors.grey.shade800),
            const SizedBox(height: 8),
            Text(
              'You saved ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(savedToday)} today',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}