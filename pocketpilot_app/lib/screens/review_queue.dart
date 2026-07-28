import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

/// Lets the user quickly confirm or correct transactions the rule-based
/// classifier could not confidently place (fixed commitment vs
/// discretionary vs transfer vs refund vs one-time exception).
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  Future<List<Transaction>>? _future;
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final future = context.read<ApiService>().getReviewQueue();
    if (!mounted) return;
    setState(() => _future = future);
  }

  Future<void> _classify(Transaction txn, TransactionClass txnClass) async {
    setState(() => _resolving.add(txn.id));
    try {
      await context.read<ApiService>().confirmClassification(txn.id, txnClass);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolving.remove(txn.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Needs Review')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: _future == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<Transaction>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data!;
                  if (list.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 48, color: Colors.green),
                                SizedBox(height: 12),
                                Text('All caught up!'),
                                SizedBox(height: 4),
                                Text(
                                  'No transactions need review right now.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (context, i) =>
                        _ReviewCard(
                      transaction: list[i],
                      busy: _resolving.contains(list[i].id),
                      onClassify: (cls) => _classify(list[i], cls),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Transaction transaction;
  final bool busy;
  final ValueChanged<TransactionClass> onClassify;

  const _ReviewCard({
    required this.transaction,
    required this.busy,
    required this.onClassify,
  });

  static const _quickOptions = [
    (TransactionClass.discretionary, 'Discretionary', Icons.shopping_bag_outlined),
    (TransactionClass.fixedCommitment, 'Fixed commitment', Icons.repeat),
    (TransactionClass.transferInternal, 'Internal transfer', Icons.swap_horiz),
    (TransactionClass.refund, 'Refund', Icons.replay),
    (TransactionClass.oneTimeException, 'One-time / emergency', Icons.priority_high),
  ];

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Opacity(
          opacity: busy ? 0.5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.merchant ?? 'Unknown merchant',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'}${currency.format(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, h:mm a').format(transaction.date),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'How should this count toward your budget?',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickOptions.map((opt) {
                  final (cls, label, icon) = opt;
                  return ActionChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(label),
                    onPressed: busy ? null : () => onClassify(cls),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
