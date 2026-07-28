import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/monthly_archive.dart';

class HistoryScreen extends StatelessWidget {
  final List<MonthlyArchive> history;
  final double lifetimeSavings;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.lifetimeSavings,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Lifetime Savings'),
                    const SizedBox(height: 6),
                    Text(
                      currency.format(lifetimeSavings),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text('No completed cycles yet'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final cycle = history[i];
                      final isPositive = cycle.totalSaved >= 0;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isPositive ? Icons.trending_up : Icons.trending_down,
                            color: isPositive
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                          ),
                          title: Text(
                            '${DateFormat('d MMM').format(cycle.cycleStart)} '
                            '\u2013 ${DateFormat('d MMM y').format(cycle.cycleEnd)}',
                          ),
                          subtitle: Text(
                            'Spent ${currency.format(cycle.totalSpent)} of '
                            '${currency.format(cycle.monthlyBudget)} plan',
                          ),
                          trailing: Text(
                            isPositive
                                ? '+${currency.format(cycle.totalSaved)}'
                                : '-${currency.format(-cycle.totalSaved)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
