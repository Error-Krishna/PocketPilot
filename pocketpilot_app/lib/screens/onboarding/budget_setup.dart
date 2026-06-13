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
  double _monthlyBudget = 5000;
  int _resetDay = 1;

  @override
  Widget build(BuildContext context) {
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
                initialValue: _monthlyBudget.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly budget (₹)', prefixText: '₹'),
                onChanged: (v) => _monthlyBudget = double.tryParse(v) ?? 0,
                validator: (v) => v == null || double.tryParse(v) == null ? 'Enter a number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _resetDay.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Budget reset day (1-31)'),
                onChanged: (v) => _resetDay = int.tryParse(v) ?? 1,
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  if (d == null || d < 1 || d > 31) return 'Day must be 1-31';
                  return null;
                },
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final api = context.read<ApiService>();
                    await api.updateUser({
                      'monthly_budget': _monthlyBudget,
                      'budget_reset_date': _resetDay,
                    });
                    if (context.mounted) context.go('/onboarding/autopay');
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