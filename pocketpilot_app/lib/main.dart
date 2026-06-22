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
import 'services/notification_service.dart';
import 'screens/autopays.dart';
import 'screens/settings.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MyApp());
// }

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
    final storage = context.read<StorageService>();
    final isLoggedIn = await auth.isSignedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      context.go('/welcome');
      return;
    }
    final onboardingDone = await storage.getOnboardingCompleted();
    if (!mounted) return;
    context.go(onboardingDone ? '/dashboard' : '/onboarding/budget');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}