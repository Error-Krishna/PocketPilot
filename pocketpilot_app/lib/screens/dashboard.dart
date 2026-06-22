import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/savings_card.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';
import '../models/budget_summary.dart';
import '../models/user.dart';
import '../services/sms_parser_service.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsParserService _smsParser = SmsParserService();
  StreamSubscription<ParsedTransaction>? _smsSubscription;
  Timer? _syncTimer;

  late Future<List<dynamic>> _combinedFuture;

  @override
  void initState() {
    super.initState();
    _smsParser.init(); // load fingerprints & last sync
    _loadData();
    _startSmsListener();
  }

  void _loadData() {
    final api = context.read<ApiService>();

    final summaryFuture = api.getBudgetSummary();
    final transactionsFuture = api
        .getTransactions()
        .then((list) => list..sort((a, b) => b.date.compareTo(a.date)));
    final savingsFuture = api.getSavingsGoals();
    final userFuture = api.getCurrentUser();

    _combinedFuture = Future.wait([
      summaryFuture,
      transactionsFuture,
      savingsFuture,
      userFuture,
    ]);
  }

  Future<void> _startSmsListener() async {
    try {
      await _smsParser.startListening();

      await _smsSubscription?.cancel();
      _smsSubscription = _smsParser.parsedTransactions.listen(
        (txn) async {
          if (!mounted) return;

          final api = context.read<ApiService>();
          final messenger = ScaffoldMessenger.of(context);

          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Detected: ₹${txn.amount.toStringAsFixed(0)} at ${txn.merchant}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          try {
            final result = await api.syncSmsTransactions([
              {
                'amount': txn.amount,
                'merchant': txn.merchant,
                'timestamp': txn.timestamp.toUtc().toIso8601String(),
                'source': txn.source,
                'raw_sms': txn.rawSms,
                'sms_fingerprint': txn.fingerprint,
              },
            ]);

            if (!mounted) return;

            if ((result['inserted'] ?? 0) > 0) {
              setState(_loadData);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Synced: ₹${txn.amount.toStringAsFixed(0)} at ${txn.merchant}',
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('SMS dashboard sync error: $e');
          }
        },
        onError: (e) => debugPrint('SMS stream error: $e'),
      );

      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
        if (!mounted) return;
        try {
          await _smsParser.syncInbox(limit: 100);
        } catch (e) {
          debugPrint('SMS inbox sync error: $e');
        }
      });

      await _smsParser.syncInbox();
    } catch (e) {
      debugPrint('SMS listener start error: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _smsSubscription?.cancel();
    _smsParser.dispose(); // close stream and clear singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_loadData);
          await _combinedFuture;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _combinedFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load dashboard',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => setState(_loadData),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final summary = snapshot.data![0] as BudgetSummary;
            final transactions = snapshot.data![1] as List<Transaction>;
            final goals = snapshot.data![2] as List<SavingsGoal>;
            final user = snapshot.data![3] as User;

            final totalSavings =
                goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount);
            final goalCount = goals.length;
            // Show persistent daily limit notification
            NotificationService.showDailyLimitNotification(
              dailyLimit: summary.dailyLimit,
              spentToday: summary.spentToday,
              savedToday: summary.savedToday,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BalanceCard(
                  userName: user.displayName,
                  monthlyBudget: summary.monthlyBudget,
                ),
                const SizedBox(height: 16),
                DailyLimitCard(
                  dailyLimit: summary.dailyLimit,
                  savedToday: summary.savedToday,
                  incomeToday: summary.incomeToday, // required
                ),
                const SizedBox(height: 16),
                SavingsCard(
                  totalSaved: totalSavings,
                  goalCount: goalCount,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                ...transactions.take(5).map((tx) => TransactionTile(
                      transaction: tx,
                      onDelete: () async {
                        await api.deleteTransaction(tx.id);
                        setState(_loadData);
                      },
                    )),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 0) return;
          if (i == 1) context.go('/transactions');
          if (i == 2) context.go('/autopays');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(
              icon: Icon(Icons.repeat), label: 'Autopays'),
        ],
      ),
    );
  }
}