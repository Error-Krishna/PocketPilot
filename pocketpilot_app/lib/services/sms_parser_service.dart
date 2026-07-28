import 'package:telephony/telephony.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ParsedTransaction {
  final double amount;
  final String merchant;
  final String source;
  final DateTime timestamp;
  final String rawSms;
  final bool isCredit;

  // Fingerprint used for dedup. Deliberately strips volatile bits (long
  // digit runs like reference/UTR numbers, and specific clock times) that
  // commonly differ between a bank's "processing" and "confirmed" SMS for
  // the very same transaction, or between a resend and the original. What's
  // left — amount, merchant/VPA, and the surrounding wording — is stable
  // across those retries while still being distinct enough to tell two
  // genuinely different transactions apart.
  String get fingerprint {
    final normalized = rawSms.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized
        .replaceAll(RegExp(r'\b\d{6,}\b'), '#') // ref/UTR numbers
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?\b'), '#'); // clock times
  }

  const ParsedTransaction({
    required this.amount,
    required this.merchant,
    required this.source,
    required this.timestamp,
    required this.rawSms,
    this.isCredit = false,
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

  // Credit (money-in) signal keywords. Kept deliberately narrower than
  // debit keywords since credit SMS are noisier (promo/reward spam uses
  // "credited" loosely) — the skip list above still runs first.
  static const List<String> _creditKeywords = [
    'credited',
    'credited to',
    'has been credited',
    'cr.',
    'received',
    'refund',
    'reversed',
    'reversal',
    'cashback',
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

  // Credit-side amount patterns — mirrors _bankPatterns but for money-in SMS.
  static final Map<String, RegExp> _creditPatterns = {
    'GENERIC_CR': RegExp(
      r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s*Cr\b',
      caseSensitive: false,
    ),
    'CREDITED': RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:has\s*been\s*)?credited',
      caseSensitive: false,
    ),
    'RECEIVED': RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:has\s*been\s*)?received',
      caseSensitive: false,
    ),
    'REFUND': RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:refunded|reversed|cashback)',
      caseSensitive: false,
    ),
  };

  // Last-resort fallback: any amount-shaped number immediately preceded by
  // a currency marker (Rs/INR/₹), regardless of the surrounding verb. Used
  // only when every bank-specific pattern above misses — this catches SMS
  // template drift (a bank rewording "debited from" to something new)
  // without needing an app update, at the cost of being less precise about
  // *which* number in the message is the transaction amount.
  static final RegExp _genericAmountPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Fallback merchant pattern for UPI VPA handles like "john@okhdfcbank" or
  // "merchantname@ybl" — common when bank SMS reference the payee's UPI ID
  // directly instead of a readable business name.
  static final RegExp _vpaPattern = RegExp(
    r'([a-zA-Z0-9.\-_]{2,})@[a-zA-Z]{2,}',
  );

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

    final isDebit = _debitKeywords.any((kw) => lower.contains(kw));
    final isCredit = _creditKeywords.any((kw) => lower.contains(kw));

    // Must contain either a debit or credit signal. If both match (some
    // bank templates reuse words like "transaction"), prefer debit since
    // that's the more common/reliable signal in Indian bank SMS templates.
    if (!isDebit && !isCredit) return null;

    final treatAsCredit = isCredit && !isDebit;

    final amount = treatAsCredit
        ? _extractCreditAmount(normalized)
        : _extractAmount(normalized);
    if (amount == null || amount <= 0) return null;

    final merchant = _extractMerchant(normalized);

    return ParsedTransaction(
      amount: amount,
      merchant: merchant,
      source: 'sms',
      timestamp: timestamp ?? DateTime.now(),
      rawSms: normalized,
      isCredit: treatAsCredit,
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
    // Fallback: no bank-specific debit pattern matched (likely a template
    // change or a bank we don't have a dedicated regex for yet). We already
    // know from _debitKeywords that this SMS is debit-shaped, so a bare
    // currency-prefixed number is a reasonable last resort.
    final fallback = _genericAmountPattern.firstMatch(body);
    if (fallback != null) {
      return _parseAmount(fallback.group(1));
    }
    return null;
  }

  double? _extractCreditAmount(String body) {
    for (final pattern in _creditPatterns.values) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1);
        return _parseAmount(raw);
      }
    }
    final fallback = _genericAmountPattern.firstMatch(body);
    if (fallback != null) {
      return _parseAmount(fallback.group(1));
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

    if (merchantMatch != null) {
      var merchant = merchantMatch.group(1)!.trim();
      merchant = merchant
          .replaceAll(
            RegExp(r'\b(ref|reference|txn|transaction).*$',
                caseSensitive: false),
            '',
          )
          .replaceAll(RegExp(r'[.,;:]+$'), '')
          .trim();
      if (merchant.isNotEmpty) return merchant;
    }

    // Fallback: pull the payee's UPI VPA handle (e.g. "johndoe@okhdfcbank")
    // when no readable "to/at/towards <name>" phrase was found. The part
    // before the @ is often a decent human-readable hint even if it's not
    // a formatted business name.
    final vpaMatch = _vpaPattern.firstMatch(body);
    if (vpaMatch != null) {
      final handle = vpaMatch.group(1)!.trim();
      if (handle.isNotEmpty) return handle;
    }

    return 'Unknown Merchant';
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