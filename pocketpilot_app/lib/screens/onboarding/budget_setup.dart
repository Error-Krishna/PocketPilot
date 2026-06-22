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
  final _resetDayCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _resetDayCtrl.dispose();
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
                decoration: const InputDecoration(labelText: 'Budget reset day (1-31)'),
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
                    try {
                      await apiService.updateUser({
                        'monthly_budget': double.parse(_budgetCtrl.text),
                        'budget_reset_date': int.parse(_resetDayCtrl.text),
                      });
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