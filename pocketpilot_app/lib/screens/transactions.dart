import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  Future<List<Transaction>>? _future;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.other;

  // Selected day filter. Null means "show all" grouped by day.
  DateTime? _selectedDate;

  void _load() {
    final future = context.read<ApiService>().getTransactions();

    if (!mounted) return;

    setState(() {
      _future = future;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Groups transactions by calendar day (most recent first), so each
  /// day's transactions are shown under their own date header.
  List<MapEntry<DateTime, List<Transaction>>> _groupByDay(
      List<Transaction> transactions) {
    final Map<DateTime, List<Transaction>> grouped = {};
    for (final txn in transactions) {
      final day = DateTime(txn.date.year, txn.date.month, txn.date.day);
      grouped.putIfAbsent(day, () => []).add(txn);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    for (final entry in entries) {
      entry.value.sort((a, b) => b.date.compareTo(a.date));
    }
    return entries;
  }

  String _dayHeaderLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(day, today)) return 'Today';
    if (_isSameDay(day, yesterday)) return 'Yesterday';
    return DateFormat('EEEE, d MMMM y').format(day);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Transaction'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description')),
              DropdownButtonFormField<TransactionType>(
                initialValue: _type,
                items: TransactionType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              DropdownButtonFormField<TransactionCategory>(
                initialValue: _category,
                items: TransactionCategory.values
                    .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final api = context.read<ApiService>();
                await api.createTransaction(TransactionCreate(
                  amount: double.parse(_amountCtrl.text),
                  type: _type,
                  category: _category,
                  description:
                      _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
                ));
                if (!mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                _load();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filter by date',
          ),
          IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: _future == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : FutureBuilder<List<Transaction>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  var list = snapshot.data!;

                  if (_selectedDate != null) {
                    list = list
                        .where((t) => _isSameDay(t.date, _selectedDate!))
                        .toList();
                  }

                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        if (_selectedDate != null) _buildFilterChip(),
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            _selectedDate != null
                                ? 'No transactions on ${DateFormat('d MMM y').format(_selectedDate!)}'
                                : 'No transactions yet',
                          ),
                        ),
                      ],
                    );
                  }

                  final grouped = _groupByDay(list);

                  return ListView.builder(
                    itemCount: grouped.length + (_selectedDate != null ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (_selectedDate != null) {
                        if (index == 0) return _buildFilterChip();
                        index -= 1;
                      }

                      final entry = grouped[index];
                      final dayTotal = entry.value
                          .where((t) => t.type == TransactionType.expense)
                          .fold<double>(0, (sum, t) => sum + t.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _dayHeaderLabel(entry.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '₹${dayTotal.toStringAsFixed(0)} spent',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...entry.value.map(
                            (txn) => TransactionTile(
                              transaction: txn,
                              onDelete: () async {
                                await api.deleteTransaction(txn.id);
                                _load();
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) context.go('/dashboard');
          if (i == 2) context.go('/autopays');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: 'Autopays'),
        ],
      ),
    );
  }

  Widget _buildFilterChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(
            'Showing ${DateFormat('d MMM y').format(_selectedDate!)}',
          ),
          onDeleted: _clearDateFilter,
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}
