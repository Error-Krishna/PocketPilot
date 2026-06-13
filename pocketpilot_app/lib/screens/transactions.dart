import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late Future<List<Transaction>> _future;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.other;

  void _load() => setState(() => _future = context.read<ApiService>().getTransactions());

  @override
  void initState() {
    super.initState();
    _load();
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
              TextFormField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              DropdownButtonFormField<TransactionType>(
                value: _type,
                items: TransactionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              DropdownButtonFormField<TransactionCategory>(
                value: _category,
                items: TransactionCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final api = context.read<ApiService>();
                await api.createTransaction(TransactionCreate(
                  amount: double.parse(_amountCtrl.text),
                  type: _type,
                  category: _category,
                  description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
                ));
                Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Transactions'), actions: [
        IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: FutureBuilder<List<Transaction>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final list = snapshot.data!;
            if (list.isEmpty) return const Center(child: Text('No transactions yet'));
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => TransactionTile(
                transaction: list[i],
                onDelete: () async {
                  await api.deleteTransaction(list[i].id);
                  _load();
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar:  BottomNavigationBar(
        currentIndex: 1,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: 'Autopays'),
        ],
      ),
    );
  }
}