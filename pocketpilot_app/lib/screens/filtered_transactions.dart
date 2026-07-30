import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../widgets/transaction_tile.dart';

/// Drill-down list for a specific slice of transactions (e.g. "everything
/// that makes up this month's spend"). Deliberately simple — a filtered,
/// read-only list with a running total header, not a full analytics view.
class FilteredTransactionsScreen extends StatelessWidget {
  final String title;
  final List<Transaction> transactions;
  final double total;

  const FilteredTransactionsScreen({
    super.key,
    required this.title,
    required this.transactions,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total'),
                    Text(
                      currency.format(total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions in this period'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (_, i) => TransactionTile(
                      transaction: transactions[i],
                      onDelete: null, // Read-only drill-down; edit from Transactions tab
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
