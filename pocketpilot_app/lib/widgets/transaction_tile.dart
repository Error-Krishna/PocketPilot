import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/bank_account.dart';

IconData categoryIcon(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.food:
      return Icons.restaurant;
    case TransactionCategory.transport:
      return Icons.directions_bus;
    case TransactionCategory.housing:
      return Icons.home;
    case TransactionCategory.entertainment:
      return Icons.movie;
    case TransactionCategory.education:
      return Icons.school;
    case TransactionCategory.gift:
      return Icons.card_giftcard;
    case TransactionCategory.oneTime:
      return Icons.warning_amber;
    case TransactionCategory.other:
      return Icons.receipt_long;
  }
}

Color classColor(TransactionClass txnClass) {
  switch (txnClass) {
    case TransactionClass.fixedCommitment:
      return const Color(0xFFF59E0B);
    case TransactionClass.discretionary:
      return const Color(0xFFEF4444);
    case TransactionClass.transferInternal:
      return const Color(0xFF6366F1);
    case TransactionClass.refund:
      return const Color(0xFF22C55E);
    case TransactionClass.incomeRegular:
      return const Color(0xFF22C55E);
    case TransactionClass.oneTimeException:
      return const Color(0xFFF97316);
    case TransactionClass.unclassified:
      return Colors.grey;
  }
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onDelete;
  final BankAccount? account;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onDelete,
    this.account,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Dismissible(
      key: Key(transaction.id),
      background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
            ) ??
            false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: () => context.push('/transaction-detail', extra: {
          'transaction': transaction,
          'account': account,
        }),
        leading: CircleAvatar(
          backgroundColor: isExpense
              ? Colors.red.withValues(alpha: 0.15)
              : Colors.green.withValues(alpha: 0.15),
          child: Icon(
            isExpense ? categoryIcon(transaction.category) : Icons.arrow_downward,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          transaction.merchant ?? transaction.category.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(DateFormat('dd MMM, h:mm a').format(transaction.date)),
            if (account != null) ...[
              const Text(' · '),
              Flexible(
                child: Text(
                  account!.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (transaction.needsReview) ...[
              const SizedBox(width: 6),
              const Icon(Icons.flag, size: 12, color: Colors.orange),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : '+'}${currency.format(transaction.amount)}',
              style: TextStyle(
                  color: isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: classColor(transaction.txnClass).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                transaction.txnClass.label,
                style: TextStyle(
                  fontSize: 10,
                  color: classColor(transaction.txnClass),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
