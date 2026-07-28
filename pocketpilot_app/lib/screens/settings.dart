import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<User>? _userFuture;
  Future<List<String>>? _selfAccountsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<ApiService>();
    setState(() {
      _userFuture = api.getCurrentUser();
      _selfAccountsFuture = api.getSelfAccounts();
    });
  }

  void _showBudgetDialog(User user) {
    final budgetCtrl =
        TextEditingController(text: user.monthlyBudget?.toStringAsFixed(0) ?? '');
    final resetDayCtrl =
        TextEditingController(text: user.budgetResetDate?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Monthly Plan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Monthly budget (₹)'),
                validator: (v) =>
                    v == null || double.tryParse(v) == null ? 'Enter a number' : null,
              ),
              TextFormField(
                controller: resetDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reset day (1-31, optional)',
                  helperText:
                      'Leave blank to let the app detect your pocket money instead.',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final d = int.tryParse(v);
                  if (d == null || d < 1 || d > 31) return 'Day must be 1-31';
                  return null;
                },
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
              if (!formKey.currentState!.validate()) return;
              final updates = <String, dynamic>{
                'monthly_budget': double.parse(budgetCtrl.text),
                'budget_reset_date':
                    resetDayCtrl.text.isEmpty ? null : int.parse(resetDayCtrl.text),
              };
              await context.read<ApiService>().updateUser(updates);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSelfAccountsDialog(List<String> current) {
    final accounts = List<String>.from(current);
    final addCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('My Own Accounts'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add names or hints that appear in your bank SMS for '
                  'accounts you own (e.g. "hdfc savings", your other bank '
                  'name). Transfers to these are excluded from spending.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: addCtrl,
                        decoration:
                            const InputDecoration(hintText: 'e.g. hdfc savings'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (addCtrl.text.trim().isEmpty) return;
                        setDialogState(() {
                          accounts.add(addCtrl.text.trim());
                          addCtrl.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: accounts.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(accounts[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setDialogState(() => accounts.removeAt(i)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<ApiService>().setSelfAccounts(accounts);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final storage = context.read<StorageService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return ListView(
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('BUDGET',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Monthly plan & reset day'),
                subtitle: user != null
                    ? Text(
                        '₹${user.monthlyBudget?.toStringAsFixed(0) ?? '—'} · '
                        '${user.budgetResetDate != null ? 'resets on day ${user.budgetResetDate}' : 'auto-detected from pocket money'}',
                      )
                    : null,
                onTap: user == null ? null : () => _showBudgetDialog(user),
              ),
              FutureBuilder<List<String>>(
                future: _selfAccountsFuture,
                builder: (context, accSnapshot) {
                  final accounts = accSnapshot.data ?? [];
                  return ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text('My own accounts'),
                    subtitle: Text(
                      accounts.isEmpty
                          ? 'None configured'
                          : accounts.join(', '),
                    ),
                    onTap: () => _showSelfAccountsDialog(accounts),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('MANAGE',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.savings),
                title: const Text('Savings goals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/savings'),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Autopays'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/autopays'),
              ),
              ListTile(
                leading: const Icon(Icons.rate_review),
                title: const Text('Review queue'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/review'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Savings history'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await context.read<ApiService>().getResetHistory();
                  if (context.mounted) {
                    context.push('/history', extra: {
                      'history': result.$1,
                      'lifetimeSavings': result.$2,
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  await auth.signOut();
                  await storage.setOnboardingCompleted(false);
                  if (context.mounted) context.go('/welcome');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
