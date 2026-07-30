class BankAccount {
  final String id;
  final String bankName;
  final String? nickname;
  final String? lastFour;
  final String accountType;
  final bool isPrimary;
  final List<String> smsHints;

  BankAccount({
    required this.id,
    required this.bankName,
    this.nickname,
    this.lastFour,
    this.accountType = 'savings',
    this.isPrimary = false,
    this.smsHints = const [],
  });

  String get displayName => nickname != null && nickname!.isNotEmpty
      ? nickname!
      : lastFour != null
          ? '$bankName •••$lastFour'
          : bankName;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'],
        bankName: json['bank_name'],
        nickname: json['nickname'],
        lastFour: json['last_four'],
        accountType: json['account_type'] ?? 'savings',
        isPrimary: json['is_primary'] ?? false,
        smsHints: List<String>.from(json['sms_hints'] ?? []),
      );
}

class BankAccountCreate {
  final String bankName;
  final String? nickname;
  final String? lastFour;
  final String accountType;
  final bool isPrimary;
  final List<String> smsHints;

  BankAccountCreate({
    required this.bankName,
    this.nickname,
    this.lastFour,
    this.accountType = 'savings',
    this.isPrimary = false,
    this.smsHints = const [],
  });

  Map<String, dynamic> toJson() => {
        'bank_name': bankName,
        if (nickname != null) 'nickname': nickname,
        if (lastFour != null) 'last_four': lastFour,
        'account_type': accountType,
        'is_primary': isPrimary,
        'sms_hints': smsHints,
      };
}

class BankAccountUpdate {
  final String? bankName;
  final String? nickname;
  final String? lastFour;
  final String? accountType;
  final bool? isPrimary;
  final List<String>? smsHints;

  BankAccountUpdate({
    this.bankName,
    this.nickname,
    this.lastFour,
    this.accountType,
    this.isPrimary,
    this.smsHints,
  });

  Map<String, dynamic> toJson() => {
        if (bankName != null) 'bank_name': bankName,
        if (nickname != null) 'nickname': nickname,
        if (lastFour != null) 'last_four': lastFour,
        if (accountType != null) 'account_type': accountType,
        if (isPrimary != null) 'is_primary': isPrimary,
        if (smsHints != null) 'sms_hints': smsHints,
      };
}
