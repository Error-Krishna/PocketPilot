import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/dashboard.dart';
import 'screens/onboarding/welcome.dart';
import 'screens/onboarding/budget_setup.dart';
import 'screens/onboarding/autopay_setup.dart';
import 'screens/onboarding/sms_permission.dart';
import 'screens/transactions.dart';
import 'screens/review_queue.dart';
import 'screens/history.dart';
import 'models/monthly_archive.dart';
import 'services/notification_service.dart';
import 'screens/autopays.dart';
import 'screens/settings.dart';
import 'screens/savings_goals.dart';
import 'screens/bank_accounts.dart';
import 'screens/transaction_detail.dart';
import 'screens/filtered_transactions.dart';
import 'models/transaction.dart';
import 'models/bank_account.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => ApiService()),
        ProxyProvider<ApiService, AuthService>(
          update: (_, api, __) => AuthService(api),
        ),
      ],
      child: _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const _SplashScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/onboarding/budget',
          builder: (_, __) => const BudgetSetupScreen(),
        ),
        GoRoute(
          path: '/onboarding/autopay',
          builder: (_, __) => const AutopaySetupScreen(),
        ),
        GoRoute(
          path: '/onboarding/sms',
          builder: (_, __) => const SmsPermissionScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, __) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/autopays',
          builder: (_, __) => const AutopaysScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/savings',
          builder: (_, __) => const SavingsGoalsScreen(),
        ),
        GoRoute(
          path: '/bank-accounts',
          builder: (_, __) => const BankAccountsScreen(),
        ),
        GoRoute(
          path: '/transaction-detail',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return TransactionDetailScreen(
              transaction: extra!['transaction'] as Transaction,
              account: extra['account'] as BankAccount?,
            );
          },
        ),
        GoRoute(
          path: '/filtered-transactions',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return FilteredTransactionsScreen(
              title: extra?['title'] as String? ?? 'Transactions',
              transactions:
                  (extra?['transactions'] as List<Transaction>?) ?? const [],
              total: (extra?['total'] as double?) ?? 0,
            );
          },
        ),
        GoRoute(
          path: '/review',
          builder: (_, __) => const ReviewQueueScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return HistoryScreen(
              history:
                  (extra?['history'] as List<MonthlyArchive>?) ?? const [],
              lifetimeSavings: (extra?['lifetimeSavings'] as double?) ?? 0,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PocketPilot',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final isLoggedIn = await auth.isSignedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      context.go('/welcome');
      return;
    }

    // Source of truth is the backend, not local storage — local flags get
    // wiped on sign-out/reinstall, but a returning user's setup already
    // exists on the server. See welcome.dart for the matching sign-in fix.
    try {
      final user = await api.getCurrentUser();
      if (!mounted) return;
      context.go(user.monthlyBudget != null ? '/dashboard' : '/onboarding/budget');
    } catch (_) {
      if (!mounted) return;
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}