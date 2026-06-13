import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.account_balance_wallet, size: 80, color: Color(0xFF38BDF8)),
            const SizedBox(height: 24),
            const Text('PocketPilot', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Take control of your student finances', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.signInWithGoogle();
                  if (context.mounted) context.go('/onboarding/budget');
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}