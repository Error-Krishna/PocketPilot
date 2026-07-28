import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/budget_summary.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  Future<List<SavingsGoal>>? _future;
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<ApiService>().getSavingsGoals();
    });
  }

  void _showGoalDialog({SavingsGoal? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(
        text: existing != null ? existing.targetAmount.toStringAsFixed(0) : '');
    final currentCtrl = TextEditingController(
        text: existing != null ? existing.currentAmount.toStringAsFixed(0) : '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New Savings Goal' : 'Edit Goal'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Goal name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target amount (₹)'),
                validator: (v) =>
                    v == null || double.tryParse(v) == null ? 'Enter a number' : null,
              ),
              TextFormField(
                controller: currentCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Already saved (₹)'),
                validator: (v) =>
                    v == null || double.tryParse(v) == null ? 'Enter a number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final api = context.read<ApiService>();
              if (existing == null) {
                await api.createSavingsGoal(SavingsGoalCreate(
                  name: nameCtrl.text,
                  targetAmount: double.parse(targetCtrl.text),
                  currentAmount: double.parse(currentCtrl.text),
                ));
              } else {
                await api.updateSavingsGoal(
                  existing.id,
                  SavingsGoalUpdate(
                    name: nameCtrl.text,
                    targetAmount: double.parse(targetCtrl.text),
                    currentAmount: double.parse(currentCtrl.text),
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context);
              _load();
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
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            onPressed: () => _showGoalDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: FutureBuilder<List<SavingsGoal>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data!;
            if (goals.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('No savings goals yet')),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _showGoalDialog(),
                      child: const Text('Add your first goal'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (_, i) {
                final goal = goals[i];
                final percent = goal.targetAmount > 0
                    ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                    : 0.0;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              goal.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () =>
                                      _showGoalDialog(existing: goal),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () async {
                                    await api.deleteSavingsGoal(goal.id);
                                    _load();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: percent),
                        const SizedBox(height: 8),
                        Text(
                          '${_currency.format(goal.currentAmount)} of ${_currency.format(goal.targetAmount)}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
