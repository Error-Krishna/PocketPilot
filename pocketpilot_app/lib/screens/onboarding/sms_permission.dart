import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';

class SmsPermissionScreen extends StatelessWidget {
  const SmsPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto‑sync SMS')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms, size: 80, color: Color(0xFF38BDF8)),
            const SizedBox(height: 24),
            const Text('Enable SMS permission', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('PocketPilot can read transaction alerts from your SMS to automatically log expenses.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                // In a real app, request SmsRetriever or telephony permission.
                final storage = context.read<StorageService>();
                await storage.setOnboardingCompleted(true);
                if (context.mounted) context.go('/dashboard');
              },
              child: const Text('Allow & finish'),
            ),
            TextButton(
              onPressed: () async {
                final storage = context.read<StorageService>();
                await storage.setOnboardingCompleted(true);
                if (context.mounted) context.go('/dashboard');
              },
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}