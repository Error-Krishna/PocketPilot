import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/autopay.dart';

class AutopaySetupScreen extends StatefulWidget {
  const AutopaySetupScreen({super.key});

  @override
  State<AutopaySetupScreen> createState() => _AutopaySetupScreenState();
}

class _AutopaySetupScreenState extends State<AutopaySetupScreen> {
  final List<AutopayCreate> _autopays = [];
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  AutopayFrequency _frequency = AutopayFrequency.monthly;
  DateTime _nextRunDate = DateTime.now().add(const Duration(days: 30));

  void _addAutopay() {
    if (_formKey.currentState!.validate()) {
      _autopays.add(AutopayCreate(
        name: _nameCtrl.text,
        amount: double.parse(_amountCtrl.text),
        frequency: _frequency,
        nextRunDate: _nextRunDate,
      ));
      _nameCtrl.clear();
      _amountCtrl.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _autopays.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_autopays[i].name),
                  subtitle: Text('${_autopays[i].amount} INR / ${_autopays[i].frequency.name}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _autopays.removeAt(i)),
                  ),
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                      TextFormField(controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                      DropdownButtonFormField<AutopayFrequency>(
                        value: _frequency,
                        items: AutopayFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
                        onChanged: (v) => setState(() => _frequency = v!),
                      ),
                      ListTile(
                        title: const Text('Next run'),
                        subtitle: Text('${_nextRunDate.toLocal()}'),
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: _nextRunDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (d != null) setState(() => _nextRunDate = d);
                        },
                      ),
                      ElevatedButton(onPressed: _addAutopay, child: const Text('Add')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final api = context.read<ApiService>();
                for (final a in _autopays) {
                  await api.createAutopay(a);
                }
                if (context.mounted) context.go('/onboarding/sms');
              },
              child: const Text('Finish setup'),
            ),
          ],
        ),
      ),
    );
  }
}