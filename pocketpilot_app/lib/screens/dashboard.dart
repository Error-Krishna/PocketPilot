import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/savings_card.dart';
import '../widgets/transaction_tile.dart';
import '../models/transaction.dart';
import '../models/budget_summary.dart';
import '../models/user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<BudgetSummary> _summaryFuture;
  late Future<List<Transaction>> _transactionsFuture;
  late Future<double> _totalSavingsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final api = context.read<ApiService>();
    _summaryFuture = api.getBudgetSummary();
    _transactionsFuture = api.getTransactions().then((list) => list..sort((a,b)=>b.date.compareTo(a.date)));
    // Fix: use 0.0 to avoid int+double issue
    _totalSavingsFuture = api.getSavingsGoals().then((goals) => goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount));
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        IconButton(onPressed: () => context.go('/settings'), icon: const Icon(Icons.settings)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _loadData()),
        child: FutureBuilder(
          future: Future.wait([_summaryFuture, _transactionsFuture, _totalSavingsFuture, api.getCurrentUser()]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final summary = snapshot.data![0] as BudgetSummary;
            final transactions = snapshot.data![1] as List<Transaction>;
            final totalSavings = snapshot.data![2] as double;
            final user = snapshot.data![3] as User;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BalanceCard(userName: user.displayName, monthlyBudget: summary.monthlyBudget),
                const SizedBox(height: 16),
                DailyLimitCard(dailyLimit: summary.dailyLimit, savedToday: summary.savedToday),
                const SizedBox(height: 16),
                SavingsCard(totalSaved: totalSavings, goalCount: 0), // goal count from separate fetch – simplified
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => context.go('/transactions'), child: const Text('See all')),
                  ],
                ),
                ...transactions.take(5).map((tx) => TransactionTile(
                  transaction: tx,
                  onDelete: () async {
                    await api.deleteTransaction(tx.id);
                    setState(() => _loadData());
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
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: 'Autopays'),
        ],
      ),
    );
  }
}