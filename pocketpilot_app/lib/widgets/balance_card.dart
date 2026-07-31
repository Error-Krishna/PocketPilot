import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BalanceCard extends StatelessWidget {
  final String userName;
  final double monthlyBudget;
  final double remainingBalance;
  final int remainingDays;
  final double? lastKnownBankBalance;
  final DateTime? lastKnownBankBalanceAt;
  final void Function(bool confirmed, double? correctedBalance, bool applyToCycle)?
      onBankBalanceReviewed;

  const BalanceCard({
    super.key,
    required this.userName,
    required this.monthlyBudget,
    required this.remainingBalance,
    required this.remainingDays,
    this.lastKnownBankBalance,
    this.lastKnownBankBalanceAt,
    this.onBankBalanceReviewed,
  });

  Future<void> _showBankBalanceDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: lastKnownBankBalance?.toStringAsFixed(0) ?? '',
    );
    bool applyToCycle = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bank Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lastKnownBankBalance != null
                    ? 'We last saw ₹${lastKnownBankBalance!.toStringAsFixed(0)} '
                        'in a bank SMS. Is this still accurate?'
                    : 'No bank balance detected yet. You can enter it manually.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Correct balance (₹)'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Also use this as this cycle\'s starting point',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Affects your daily limit — only turn on if you\'re '
                  'correcting a real mismatch, not just noting the balance.',
                  style: TextStyle(fontSize: 11),
                ),
                value: applyToCycle,
                onChanged: (v) => setDialogState(() => applyToCycle = v ?? false),
              ),
            ],
          ),
          actions: [
            if (lastKnownBankBalance != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onBankBalanceReviewed?.call(true, null, false);
                },
                child: const Text('Looks right'),
              ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(ctrl.text);
                Navigator.pop(dialogContext);
                if (value != null) {
                  onBankBalanceReviewed?.call(false, value, applyToCycle);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _showBankBalanceDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.account_balance,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lastKnownBankBalance != null
                            ? 'Bank shows ~₹${lastKnownBankBalance!.toStringAsFixed(0)} '
                                '(tap to confirm or edit)'
                            : 'Bank balance not detected yet — tap to add',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.edit, size: 12, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}