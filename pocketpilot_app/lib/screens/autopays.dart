import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/autopay.dart';

class AutopaysScreen extends StatefulWidget {
  const AutopaysScreen({super.key});

  @override
  State<AutopaysScreen> createState() => _AutopaysScreenState();
}

class _AutopaysScreenState extends State<AutopaysScreen> {
  late Future<List<Autopay>> _future;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  AutopayFrequency _frequency = AutopayFrequency.monthly;
  DateTime _nextRunDate = DateTime.now().add(const Duration(days: 30));

  void _load() => setState(() => _future = context.read<ApiService>().getAutopays());

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Autopay'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final api = context.read<ApiService>();
                await api.createAutopay(AutopayCreate(
                  name: _nameCtrl.text,
                  amount: double.parse(_amountCtrl.text),
                  frequency: _frequency,
                  nextRunDate: _nextRunDate,
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
      appBar: AppBar(title: const Text('Autopays'), actions: [
        IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: FutureBuilder<List<Autopay>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final list = snapshot.data!;
            if (list.isEmpty) return const Center(child: Text('No autopays set'));
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => Dismissible(
                key: Key(list[i].id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete)),
                onDismissed: (_) async {
                  await api.deleteAutopay(list[i].id);
                  _load();
                },
                child: ListTile(
                  title: Text(list[i].name),
                  subtitle: Text('${list[i].amount} INR / ${list[i].frequency.name} • Next: ${list[i].nextRunDate.toLocal().toString().substring(0, 10)}'),
                  trailing: Switch(
                    value: list[i].isActive,
                    onChanged: (val) async {
                      await api.updateAutopay(list[i].id, AutopayUpdate(isActive: val));
                      _load();
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) context.go('/dashboard');
          if (i == 1) context.go('/transactions');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: 'Autopays'),
        ],
      ),
    );
  }
}