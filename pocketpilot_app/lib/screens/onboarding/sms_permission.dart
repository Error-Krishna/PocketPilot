import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';

import '../../services/api_service.dart';
import '../../services/sms_parser_service.dart';
import '../../services/storage_service.dart';
import '../../services/battery_optimization_service.dart';

class SmsPermissionScreen extends StatefulWidget {
  const SmsPermissionScreen({super.key});

  @override
  State<SmsPermissionScreen> createState() => _SmsPermissionScreenState();
}

class _SmsPermissionScreenState extends State<SmsPermissionScreen> {
  final Telephony _telephony = Telephony.instance;
  final SmsParserService _smsParserService = SmsParserService();
  StreamSubscription<ParsedTransaction>? _smsSubscription;
  bool _isSubmitting = false;
  bool _permissionGranted = false;

  Future<void> _continue() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = context.read<ApiService>();
      final storage = context.read<StorageService>();
      final messenger = ScaffoldMessenger.of(context);
      final granted = await _telephony.requestPhoneAndSmsPermissions;
      if (granted != true) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'SMS permission was denied. You can enable it later in settings.'),
          ),
        );
        return;
      }

      _permissionGranted = true;
      await _smsParserService.startListening();

      if (_smsSubscription != null) {
        await _smsSubscription!.cancel();
      }
      _smsSubscription = _smsParserService.parsedTransactions.listen((parsed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Detected transaction: ₹${parsed.amount.toStringAsFixed(0)} at ${parsed.merchant}',
            ),
          ),
        );
        unawaited(_syncParsedTransaction(api, messenger, parsed));
      });

      await _smsParserService.syncInbox();

      await storage.setOnboardingCompleted(true);

      if (!mounted) return;
      await _maybePromptBatteryExemption();

      if (!mounted) return;
      context.go('/dashboard');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start SMS syncing right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _syncParsedTransaction(ApiService api,
      ScaffoldMessengerState messenger, ParsedTransaction parsed) async {
    try {
      await api.syncSmsTransactions([
        {
          'amount': parsed.amount,
          'merchant': parsed.merchant,
          'timestamp': parsed.timestamp.toUtc().toIso8601String(),
          'source': 'sms',
          'raw_sms': parsed.rawSms,
          'sms_fingerprint': parsed.fingerprint,
          'is_credit': parsed.isCredit,
        },
      ]);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Transaction synced: ₹${parsed.amount.toStringAsFixed(0)} at ${parsed.merchant}',
          ),
        ),
      );
    } catch (_) {
      // Non-fatal: sync will retry on next inbox scan.
    }
  }

  Future<void> _maybePromptBatteryExemption() async {
    final alreadyExempted =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (alreadyExempted || !mounted) return;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keep transaction detection reliable'),
        content: const Text(
          'Android may pause apps running in the background to save '
          'battery. To make sure PocketPilot keeps detecting transactions '
          'even when closed, allow it to run in the background on the '
          'next screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      await BatteryOptimizationService.requestExemption();
    }
  }

  Future<void> _skip() async {
    final storage = context.read<StorageService>();
    await storage.setOnboardingCompleted(true);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-sync SMS')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms, size: 80, color: Color(0xFF38BDF8)),
            const SizedBox(height: 24),
            const Text(
              'Enable SMS permission',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'PocketPilot can read transaction alerts from your SMS to automatically log expenses.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _permissionGranted
                  ? 'SMS permission granted. Listener is active.'
                  : 'We will only read debit alerts for automatic expense tracking.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _continue,
              child: Text(_isSubmitting ? 'Working...' : 'Continue'),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _skip,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
