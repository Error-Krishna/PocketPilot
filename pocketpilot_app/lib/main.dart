import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/dashboard.dart';
import 'screens/onboarding/welcome.dart';
import 'screens/onboarding/budget_setup.dart';
import 'screens/onboarding/autopay_setup.dart';
import 'screens/onboarding/sms_permission.dart';
import 'screens/transactions.dart';
import 'screens/autopays.dart';
import 'screens/settings.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final auth = context.read<AuthService>();
      final storage = context.read<StorageService>();
      final isLoggedIn = await auth.isSignedIn();
      if (!isLoggedIn) return '/welcome';
      final onboardingDone = await storage.getOnboardingCompleted();
      if (!onboardingDone) return '/onboarding/budget';
      return '/dashboard';
    },
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (_, __) => WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/budget',
        name: 'budgetSetup',
        builder: (_, __) => BudgetSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/autopay',
        name: 'autopaySetup',
        builder: (_, __) => AutopaySetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/sms',
        name: 'smsPermission',
        builder: (_, __) => SmsPermissionScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (_, __) => DashboardScreen(),
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        builder: (_, __) => TransactionsScreen(),
      ),
      GoRoute(
        path: '/autopays',
        name: 'autopays',
        builder: (_, __) => AutopaysScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => SettingsScreen(),
      ),
    ],
  );

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
      child: MaterialApp.router(
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
      ),
    );
  }
}