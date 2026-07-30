import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BalanceCard extends StatelessWidget {
  final String userName;
  final double monthlyBudget;
  final double remainingBalance;
  final int remainingDays;
  final double? lastKnownBankBalance;
  final DateTime? lastKnownBankBalanceAt;

  const BalanceCard({
    super.key,
    required this.userName,
    required this.monthlyBudget,
    required this.remainingBalance,
    required this.remainingDays,
    this.lastKnownBankBalance,
    this.lastKnownBankBalanceAt,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isOverspent = remainingBalance < 0;

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
              isOverspent ? 'Over budget by' : 'Left to spend this month',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            Text(
              currency.format(remainingBalance.abs()),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isOverspent ? const Color(0xFFEF4444) : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${currency.format(monthlyBudget)} monthly plan · '
              '$remainingDays day${remainingDays == 1 ? '' : 's'} left',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            if (lastKnownBankBalance != null) ...[
              const SizedBox(height: 10),
              Text(
                'Bank shows ~₹${lastKnownBankBalance!.toStringAsFixed(0)} '
                '(reference only, from last SMS)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}