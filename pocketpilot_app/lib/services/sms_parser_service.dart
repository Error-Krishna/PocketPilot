import 'package:telephony/telephony.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
  static SmsParserService? _instance;

  factory SmsParserService({Telephony? telephony}) {
    _instance ??= SmsParserService._internal(telephony);
    return _instance!;
  }

  SmsParserService._internal(Telephony? telephony)
      : _telephony = telephony ?? Telephony.instance;

  final Telephony _telephony;
  bool _listenerStarted = false;
  static const int _maxFingerprintCacheSize = 2000;
  final Set<String> _processedFingerprints = <String>{};

  final StreamController<ParsedTransaction> _parsedTransactionsController =
      StreamController<ParsedTransaction>.broadcast();

  Stream<ParsedTransaction> get parsedTransactions =>
      _parsedTransactionsController.stream;

  // Persistence keys
  static const String _fingerprintsKey = 'sms_fingerprints';
  static const String _lastSyncKey = 'sms_last_sync';

  // ---------------------------------------------------------------------------
  // Singleton lifecycle
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    await _loadFingerprints();
    // last sync timestamp is read on demand in syncInbox()
  }

  void dispose() {
    _parsedTransactionsController.close();
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // SMS classification (one unified list)
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
    'dr.',
  ];

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
    final lastSync = await _getLastSyncTimestamp();
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.BODY, SmsColumn.DATE],
    );

    final sorted = messages.toList()
      ..sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));

    // Only process messages newer than lastSync
    final filtered = sorted.where((msg) {
      if (msg.date == null) return true;
      return msg.date! > lastSync;
    }).toList();

    var emitted = 0;
    for (final message in filtered.take(limit)) {
      final parsed = parseSms(
        message.body ?? '',
        timestamp: message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!)
            : DateTime.now(),
      );
      if (_emitParsed(parsed)) emitted++;
    }

    // Update last sync timestamp to now
    await _saveLastSync(DateTime.now().millisecondsSinceEpoch);

    return emitted;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------
  bool _emitParsed(ParsedTransaction? parsed) {
    if (parsed == null) return false;

    final fp = parsed.fingerprint;
    if (_processedFingerprints.contains(fp)) return false;

    if (_processedFingerprints.length >= _maxFingerprintCacheSize) {
      _processedFingerprints.remove(_processedFingerprints.first);
    }

    _processedFingerprints.add(fp);
    _parsedTransactionsController.add(parsed);
    _saveFingerprints(); // persist
    return true;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------
  Future<void> _loadFingerprints() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_fingerprintsKey) ?? [];
    _processedFingerprints.addAll(list);
  }

  Future<void> _saveFingerprints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_fingerprintsKey, _processedFingerprints.toList());
  }

  Future<int> _getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncKey) ?? 0;
  }

  Future<void> _saveLastSync(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, timestamp);
  }

  // ---------------------------------------------------------------------------
  // Public parsing method (stateless, testable)
  // ---------------------------------------------------------------------------
  ParsedTransaction? parseSms(String body, {DateTime? timestamp}) {
    final normalized = body.trim();
    if (normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();

    // Use the class-level _skipKeywords
    if (_skipKeywords.any((kw) => lower.contains(kw))) return null;

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