import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController(text: '5000');
  final _resetDayCtrl = TextEditingController();
  final _startingBalanceCtrl = TextEditingController();
  bool _alreadyHaveSomeLeft = false;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _resetDayCtrl.dispose();
    _startingBalanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.read<ApiService>(); // Get ApiService from Provider

    return Scaffold(
      appBar: AppBar(title: const Text('Set monthly budget')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Spacer(),
              const Text('How much can you spend each month?', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly budget (₹)', prefixText: '₹'),
                validator: (v) => v == null || double.tryParse(v) == null ? 'Enter a number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resetDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget reset day (1-31, optional)',
                  helperText: 'Leave blank if unsure — the app can still detect '
                      'your pocket money arriving instead.',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final d = int.tryParse(v);
                  if (d == null || d < 1 || d > 31) return 'Day must be 1-31';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I already have some money left from this cycle'),
                subtitle: const Text(
                  'Turn this on if you\'re setting up mid-cycle and already '
                  'spent part of this month\'s pocket money.',
                ),
                value: _alreadyHaveSomeLeft,
                onChanged: (v) => setState(() => _alreadyHaveSomeLeft = v),
              ),
              if (_alreadyHaveSomeLeft) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _startingBalanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'How much do you have left right now? (₹)',
                    prefixText: '₹',
                  ),
                  validator: (v) {
                    if (!_alreadyHaveSomeLeft) return null;
                    if (v == null || double.tryParse(v) == null) {
                      return 'Enter a number';
                    }
                    return null;
                  },
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final updates = <String, dynamic>{
                        'monthly_budget': double.parse(_budgetCtrl.text),
                      };
                      if (_resetDayCtrl.text.isNotEmpty) {
                        updates['budget_reset_date'] = int.parse(_resetDayCtrl.text);
                      }
                      if (_alreadyHaveSomeLeft && _startingBalanceCtrl.text.isNotEmpty) {
                        updates['cycle_starting_balance'] =
                            double.parse(_startingBalanceCtrl.text);
                      }
                      await apiService.updateUser(updates);
                      if (context.mounted) context.go('/onboarding/autopay');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}