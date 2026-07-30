import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/bank_account.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  Future<List<BankAccount>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<ApiService>().getBankAccounts();
    });
  }

  void _showAccountDialog({BankAccount? existing}) {
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    final nicknameCtrl = TextEditingController(text: existing?.nickname ?? '');
    final lastFourCtrl = TextEditingController(text: existing?.lastFour ?? '');
    final hintsCtrl =
        TextEditingController(text: existing?.smsHints.join(', ') ?? '');
    bool isPrimary = existing?.isPrimary ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Bank Account' : 'Edit Account'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: bankNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Bank name (e.g. HDFC, SBI)'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: nicknameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nickname (optional)',
                      helperText: 'e.g. "Main account", "Dad\'s account"',
                    ),
                  ),
                  TextFormField(
                    controller: lastFourCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 digits (optional)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length != 4 || int.tryParse(v) == null) {
                        return 'Enter exactly 4 digits';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: hintsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SMS hints (comma separated, optional)',
                      helperText:
                          'Extra words from this bank\'s SMS to help match it',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primary account'),
                    value: isPrimary,
                    onChanged: (v) => setDialogState(() => isPrimary = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final api = context.read<ApiService>();
                final hints = hintsCtrl.text
                    .split(',')
                    .map((h) => h.trim())
                    .where((h) => h.isNotEmpty)
                    .toList();

                if (existing == null) {
                  await api.createBankAccount(BankAccountCreate(
                    bankName: bankNameCtrl.text,
                    nickname:
                        nicknameCtrl.text.isEmpty ? null : nicknameCtrl.text,
                    lastFour:
                        lastFourCtrl.text.isEmpty ? null : lastFourCtrl.text,
                    isPrimary: isPrimary,
                    smsHints: hints,
                  ));
                } else {
                  await api.updateBankAccount(
                    existing.id,
                    BankAccountUpdate(
                      bankName: bankNameCtrl.text,
                      nickname:
                          nicknameCtrl.text.isEmpty ? null : nicknameCtrl.text,
                      lastFour:
                          lastFourCtrl.text.isEmpty ? null : lastFourCtrl.text,
                      isPrimary: isPrimary,
                      smsHints: hints,
                    ),
                  );
                }
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
    final api = context.read<ApiService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          IconButton(
            onPressed: () => _showAccountDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: FutureBuilder<List<BankAccount>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final accounts = snapshot.data!;
            if (accounts.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Add your bank accounts so transactions can be '
                        'tagged with the right one, and transfers between '
                        'your own accounts are detected automatically.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _showAccountDialog(),
                      child: const Text('Add your first account'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              itemBuilder: (_, i) {
                final account = accounts[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.account_balance,
                      color: account.isPrimary
                          ? const Color(0xFF38BDF8)
                          : Colors.grey,
                    ),
                    title: Text(account.displayName),
                    subtitle: Text(
                      account.isPrimary
                          ? 'Primary · ${account.bankName}'
                          : account.bankName,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () =>
                              _showAccountDialog(existing: account),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () async {
                            await api.deleteBankAccount(account.id);
                            _load();
                          },
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
