import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/bank_account.dart';
import '../services/api_service.dart';
import '../widgets/transaction_tile.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final BankAccount? account;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.account,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final color = isExpense ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('This can\'t be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<ApiService>().deleteTransaction(transaction.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Big hero amount, GPay-style ---
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    isExpense
                        ? categoryIcon(transaction.category)
                        : Icons.arrow_downward,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${isExpense ? '-' : '+'}${currency.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  transaction.merchant ?? transaction.category.label,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM y · h:mm a').format(transaction.date),
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- Detail rows, GPay/PhonePe style ---
          _DetailCard(
            children: [
              _DetailRow(
                label: 'Status',
                value: transaction.needsReview ? 'Needs review' : 'Confirmed',
                valueColor: transaction.needsReview ? Colors.orange : Colors.green,
              ),
              _DetailRow(
                label: 'Type',
                value: transaction.txnClass.label,
                valueColor: classColor(transaction.txnClass),
              ),
              _DetailRow(label: 'Category', value: transaction.category.label),
              _DetailRow(
                label: 'Source',
                value: transaction.source == 'sms' ? 'Detected from SMS' : 'Manually added',
              ),
              if (account != null)
                _DetailRow(label: 'Account', value: account!.displayName),
              if (transaction.description != null &&
                  transaction.description!.isNotEmpty)
                _DetailRow(label: 'Note', value: transaction.description!),
            ],
          ),

          if (transaction.rawSms != null && transaction.rawSms!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'ORIGINAL SMS',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.rawSms!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: transaction.rawSms!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Transaction ID: ${transaction.id}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
