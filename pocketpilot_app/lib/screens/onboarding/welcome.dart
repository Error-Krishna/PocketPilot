import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isSigningIn = false;

  Future<void> _handleSignIn() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    setState(() => _isSigningIn = true);

    try {
      await auth.signInWithGoogle();
      if (!mounted) return;

      // Source of truth for "has this user already completed setup" is the
      // backend, not a local device flag — flutter_secure_storage gets
      // wiped on sign-out, but a returning user's account and budget data
      // still exist on the server. Checking monthly_budget here is what
      // actually lets a returning user skip onboarding after signing back
      // in, instead of being forced through setup again every time.
      final user = await api.getCurrentUser();
      if (!mounted) return;

      if (user.monthlyBudget != null) {
        context.go('/dashboard');
      } else {
        context.go('/onboarding/budget');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _isSigningIn ? null : _handleSignIn,
                icon: _isSigningIn
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_isSigningIn ? 'Signing in...' : 'Sign in with Google'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}