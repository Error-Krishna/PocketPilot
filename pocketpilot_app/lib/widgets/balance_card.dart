import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BalanceCard extends StatelessWidget {
  final String userName;
  final double monthlyBudget;

  const BalanceCard({super.key, required this.userName, required this.monthlyBudget});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Monthly Budget',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            Text(
              NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(monthlyBudget),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}