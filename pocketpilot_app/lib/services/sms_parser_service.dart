// lib/services/sms_parser_service.dart
import 'package:telephony/telephony.dart';
import 'dart:async';

class ParsedTransaction {
  final double amount;
  final String merchant;
  final String source;
  final DateTime timestamp;
  final String rawSms;

  String get fingerprint =>
      rawSms.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  const ParsedTransaction({
    required this.amount,
    required this.merchant,
    required this.source,
    required this.timestamp,
    required this.rawSms,
  });
}

class SmsParserService {
  // ---------------------------------------------------------------------------
  // Singleton factory
  // ---------------------------------------------------------------------------
  static SmsParserService? _instance;

  factory SmsParserService({Telephony? telephony}) {
    _instance ??= SmsParserService._internal(telephony);
    return _instance!;
  }

  SmsParserService._internal(Telephony? telephony)
      : _telephony = telephony ?? Telephony.instance;

  final Telephony _telephony;

  // ---------------------------------------------------------------------------
  // Instance state (was static before)
  // ---------------------------------------------------------------------------
  bool _listenerStarted = false;
  static const int _maxFingerprintCacheSize = 2000;
  final Set<String> _processedFingerprints = <String>{};

  final StreamController<ParsedTransaction> _parsedTransactionsController =
      StreamController<ParsedTransaction>.broadcast();

  Stream<ParsedTransaction> get parsedTransactions =>
      _parsedTransactionsController.stream;

  // ---------------------------------------------------------------------------
  // SMS classification config (updated skips)
  // ---------------------------------------------------------------------------
  static const List<String> _skipKeywords = [
    'otp',
    'your account is credited',
    'credit for',
    'statement',
    'mini statement',
    'emi due',
    'credit limit',
    'reward points',
    'loan',
    'minimum due',
    'upcoming mandate',
    'upi mandate',
    'for the autopay',
    'reverse atm',
    // 'available balance' removed – it appears in debit SMS too
  ];

  static const List<String> _debitKeywords = [
    'debited',
    'paid',
    'sent',
    'spent',
    'withdrawn',
    'used',
    'purchase',
    'purchased',
    'payment',
    'txn',
    'transaction',
    'dr.', // keep this
    // 'cr ' removed – not a reliable debit indicator
  ];

  // BOB pattern fixed with word boundary after Dr
  static final Map<String, RegExp> _bankPatterns = {
    'BOB': RegExp(
      r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s*Dr\b',
      caseSensitive: false,
    ),
    'SBI': RegExp(
      r'debited\s+(?:by\s+)?Rs\.?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    'HDFC': RegExp(
      r'Rs\s*([\d,]+(?:\.\d{1,2})?)\s*debited\s*from',
      caseSensitive: false,
    ),
    'ICICI': RegExp(
      r'INR\s*([\d,]+(?:\.\d{1,2})?)\s*debited',
      caseSensitive: false,
    ),
    'AXIS': RegExp(
      r'INR\s*([\d,]+(?:\.\d{1,2})?)\s*has\s*been\s*debited',
      caseSensitive: false,
    ),
    'UPI': RegExp(
      r'(?:paid|sent|debited).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
      dotAll: true,
    ),
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------
  Future<void> startListening() async {
    if (_listenerStarted) return;
    _listenerStarted = true;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        final parsed = parseSms(
          message.body ?? '',
          timestamp: message.date != null
              ? DateTime.fromMillisecondsSinceEpoch(message.date!)
              : DateTime.now(),
        );
        _emitParsed(parsed);
      },
      onBackgroundMessage: telephonyBackgroundSmsHandler,
    );
  }

  Future<int> syncInbox({int limit = 50}) async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.BODY, SmsColumn.DATE],
    );

    final sorted = messages.toList()
      ..sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));

    var emitted = 0;
    for (final message in sorted.take(limit)) {
      final parsed = parseSms(
        message.body ?? '',
        timestamp: message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!)
            : DateTime.now(),
      );
      if (_emitParsed(parsed)) emitted++;
    }
    return emitted;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------
  bool _emitParsed(ParsedTransaction? parsed) {
    if (parsed == null) return false;

    final fp = parsed.fingerprint;
    if (_processedFingerprints.contains(fp)) return false;

    // Bounded cache: evict oldest when full
    if (_processedFingerprints.length >= _maxFingerprintCacheSize) {
      _processedFingerprints.remove(_processedFingerprints.first);
    }

    _processedFingerprints.add(fp);
    _parsedTransactionsController.add(parsed);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Public parsing method (stateless, testable)
  // ---------------------------------------------------------------------------
  ParsedTransaction? parseSms(String body, {DateTime? timestamp}) {
    final normalized = body.trim();
    if (normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();

    // Hard skips
    const hardSkips = [
      'otp',
      'your account is credited',
      'credit for',
      'statement',
      'mini statement',
      'emi due',
      'credit limit',
      'reward points',
      'loan',
      'minimum due',
      'upcoming mandate',
      'upi mandate',
      'for the autopay',
      'reverse atm',
    ];
    if (hardSkips.any((kw) => lower.contains(kw))) return null;

    // Must contain a debit signal
    if (!_debitKeywords.any((kw) => lower.contains(kw))) return null;

    final amount = _extractAmount(normalized);
    if (amount == null || amount <= 0) return null;

    final merchant = _extractMerchant(normalized);

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      source: 'sms',
      timestamp: timestamp ?? DateTime.now(),
      rawSms: normalized,
    );
  }

  double? _extractAmount(String body) {
    for (final pattern in _bankPatterns.values) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1);
        return _parseAmount(raw);
      }
    }
    return null;
  }

  String _extractMerchant(String body) {
    final bobMatch = RegExp(
      r'Cr\.\s*to\s+([^\s.]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (bobMatch != null) {
      return bobMatch.group(1)!.trim().replaceAll(RegExp(r'[.,;:]+$'), '');
    }

    final merchantMatch = RegExp(
      r'(?:to|at|towards)\s+([^.,;:\n]+?)(?:\s+(?:using|via|through|from|with|for|txn|transaction|upi)\b|[.,;:\n]|$)',
      caseSensitive: false,
    ).firstMatch(body);

    if (merchantMatch == null) return 'Unknown Merchant';

    var merchant = merchantMatch.group(1)!.trim();
    merchant = merchant
        .replaceAll(
          RegExp(r'\b(ref|reference|txn|transaction).*$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[.,;:]+$'), '')
        .trim();

    return merchant.isEmpty ? 'Unknown Merchant' : merchant;
  }

  double? _parseAmount(String? rawAmount) {
    if (rawAmount == null || rawAmount.isEmpty) return null;
    return double.tryParse(rawAmount.replaceAll(',', ''));
  }

  // For testing only
  static void resetForTesting() {
    _instance?._parsedTransactionsController.close();
    _instance = null;
  }
}

void telephonyBackgroundSmsHandler(SmsMessage message) {
  // Background handler – minimal as per plugin requirements
}