import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onDelete;

  const TransactionTile({super.key, required this.transaction, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    return Dismissible(
      key: Key(transaction.id),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
          child: Icon(isExpense ? Icons.shopping_cart : Icons.attach_money, color: isExpense ? Colors.red : Colors.green),
        ),
        title: Text(transaction.merchant ?? transaction.category.toString().split('.').last),
        subtitle: Text(DateFormat('dd MMM yyyy').format(transaction.date)),
        trailing: Text(
          '${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(transaction.amount)}',
          style: TextStyle(color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}