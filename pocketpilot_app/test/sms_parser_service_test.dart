import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpilot/services/sms_parser_service.dart';

void main() {
  final service = SmsParserService();

  group('SmsParserService', () {
    test('parses SBI debit SMS', () {
      final parsed = service.parseSms(
        'Your A/c XX1234 has been debited by Rs. 1,500 for payment to Big Bazaar.',
        timestamp: DateTime(2026, 6, 17),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1500);
      expect(parsed.merchant, 'Big Bazaar');
      expect(parsed.source, 'sms');
      expect(parsed.rawSms, contains('debited by Rs. 1,500'));
    });

    test('parses BOB credit/debit transfer SMS', () {
      final parsed = service.parseSms(
        'Rs.1.00 Dr. from A/C XXXXXX9890 and Cr. to sumangoyal09@ybl. Ref:617101871255. AvlBal:Rs7808.66(2026:06:20 03:59:49). Not you? Call 18005700/5000-BOB',
        timestamp: DateTime(2026, 6, 20, 3, 59, 49),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1.00);
      expect(parsed.merchant, 'sumangoyal09@ybl');
      expect(parsed.source, 'sms');
    });

    test('parses HDFC debit SMS', () {
      final parsed = service.parseSms(
        'Rs 2,450 debited from your HDFC Bank account towards Amazon Pay.',
        timestamp: DateTime(2026, 6, 17),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 2450);
      expect(parsed.merchant, 'Amazon Pay');
    });

    test('parses ICICI debit SMS', () {
      final parsed = service.parseSms(
        'INR 799 debited from a/c XX1234 towards Zomato.',
        timestamp: DateTime(2026, 6, 17),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 799);
      expect(parsed.merchant, 'Zomato');
    });

    test('parses Axis debit SMS', () {
      final parsed = service.parseSms(
        'INR 1,200 has been debited from your Axis Bank account at Swiggy.',
        timestamp: DateTime(2026, 6, 17),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200);
      expect(parsed.merchant, 'Swiggy');
    });

    test('parses UPI debit SMS', () {
      final parsed = service.parseSms(
        'You have paid INR 350 towards Ola Cabs using UPI.',
        timestamp: DateTime(2026, 6, 17),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 350);
      expect(parsed.merchant, 'Ola Cabs');
    });

    test('returns null for credit or OTP messages', () {
      expect(
        service.parseSms('Your OTP is 123456 for login.'),
        isNull,
      );

      expect(
        service.parseSms('Rs 1,000 credited to your account.'),
        isNull,
      );
    });

    test('returns null for unrecognized sms', () {
      expect(
        service.parseSms('Welcome to PocketPilot.'),
        isNull,
      );
    });
  });
}
