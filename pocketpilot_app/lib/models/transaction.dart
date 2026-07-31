enum TransactionType { income, expense }

enum TransactionCategory {
  food,
  transport,
  housing,
  entertainment,
  education,
  gift,
  oneTime,
  other
}

/// How a transaction affects the user's monthly spending PLAN.
/// Orthogonal to [TransactionType] and [TransactionCategory].
enum TransactionClass {
  fixedCommitment,
  discretionary,
  transferInternal,
  refund,
  incomeRegular,
  oneTimeException,
  unclassified,
}

enum ClassificationSource { rule, user, pending }

TransactionClass _transactionClassFromJson(String? value) {
  switch (value) {
    case 'fixed_commitment':
      return TransactionClass.fixedCommitment;
    case 'transfer_internal':
      return TransactionClass.transferInternal;
    case 'refund':
      return TransactionClass.refund;
    case 'income_regular':
      return TransactionClass.incomeRegular;
    case 'one_time_exception':
      return TransactionClass.oneTimeException;
    case 'unclassified':
      return TransactionClass.unclassified;
    default:
      return TransactionClass.discretionary;
  }
}

String _transactionClassToJson(TransactionClass value) {
  switch (value) {
    case TransactionClass.fixedCommitment:
      return 'fixed_commitment';
    case TransactionClass.discretionary:
      return 'discretionary';
    case TransactionClass.transferInternal:
      return 'transfer_internal';
    case TransactionClass.refund:
      return 'refund';
    case TransactionClass.incomeRegular:
      return 'income_regular';
    case TransactionClass.oneTimeException:
      return 'one_time_exception';
    case TransactionClass.unclassified:
      return 'unclassified';
  }
}

extension TransactionClassLabel on TransactionClass {
  String get label => switch (this) {
        TransactionClass.fixedCommitment => 'Fixed commitment',
        TransactionClass.discretionary => 'Discretionary spend',
        TransactionClass.transferInternal => 'Internal transfer',
        TransactionClass.refund => 'Refund',
        TransactionClass.incomeRegular => 'Income',
        TransactionClass.oneTimeException => 'One-time exception',
        TransactionClass.unclassified => 'Needs review',
      };

  /// Public wire-format serializer, used by ApiService when submitting a
  /// user's classification decision back to the backend.
  String get wireValue => _transactionClassToJson(this);
}

ClassificationSource _classificationSourceFromJson(String? value) {
  switch (value) {
    case 'rule':
      return ClassificationSource.rule;
    case 'pending':
      return ClassificationSource.pending;
    default:
      return ClassificationSource.user;
  }
}

TransactionType _transactionTypeFromJson(String value) =>
    value == 'income' ? TransactionType.income : TransactionType.expense;

String _transactionTypeToJson(TransactionType value) =>
    value == TransactionType.income ? 'income' : 'expense';

TransactionCategory _transactionCategoryFromJson(String value) {
  switch (value) {
    case 'food':
      return TransactionCategory.food;
    case 'transport':
      return TransactionCategory.transport;
    case 'housing':
      return TransactionCategory.housing;
    case 'entertainment':
      return TransactionCategory.entertainment;
    case 'education':
      return TransactionCategory.education;
    case 'gift':
      return TransactionCategory.gift;
    case 'one_time':
      return TransactionCategory.oneTime;
    default:
      return TransactionCategory.other;
  }
}

String _transactionCategoryToJson(TransactionCategory value) {
  switch (value) {
    case TransactionCategory.food:
      return 'food';
    case TransactionCategory.transport:
      return 'transport';
    case TransactionCategory.housing:
      return 'housing';
    case TransactionCategory.entertainment:
      return 'entertainment';
    case TransactionCategory.education:
      return 'education';
    case TransactionCategory.gift:
      return 'gift';
    case TransactionCategory.oneTime:
      return 'one_time';
    case TransactionCategory.other:
      return 'other';
  }
}

extension TransactionCategoryLabel on TransactionCategory {
  String get label => switch (this) {
        TransactionCategory.oneTime => 'one time',
        _ => name,
      };
}

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final String? merchant;
  final String source;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TransactionClass txnClass;
  final ClassificationSource classificationSource;
  final double classificationConfidence;
  final String? accountId;
  final String? rawSms;
  final String? classificationRule;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.merchant,
    required this.source,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.txnClass = TransactionClass.discretionary,
    this.classificationSource = ClassificationSource.user,
    this.classificationConfidence = 1.0,
    this.accountId,
    this.rawSms,
    this.classificationRule,
  });

  bool get needsReview => classificationSource == ClassificationSource.pending;

  /// Human-readable explanation of why the classifier reached its
  /// decision, derived from the raw rule code (e.g. "discretionary_kw:
  /// swiggy"). Falls back to a generic note for manual entries or when no
  /// rule was recorded (older transactions predate this field).
  String get classificationExplanation {
    final rule = classificationRule;
    if (classificationSource == ClassificationSource.user) {
      return 'You confirmed this classification.';
    }
    if (rule == null) {
      return 'No detailed reason recorded for this transaction.';
    }
    final parts = rule.split(':');
    final kind = parts[0];
    final matched = parts.length > 1 ? parts[1] : null;

    switch (kind) {
      case 'autopay_name':
        return 'Matched your autopay named "$matched".';
      case 'self_account':
        return 'Matched your registered account "$matched".';
      case 'income_kw':
        return 'Detected the income keyword "$matched" in the SMS.';
      case 'refund_kw':
        return 'Detected the refund keyword "$matched" in the SMS.';
      case 'fixed_kw':
        return 'Detected the keyword "$matched", suggesting a recurring bill or subscription.';
      case 'transfer_kw':
        return 'Detected the keyword "$matched", suggesting a transfer between your own accounts.';
      case 'exception_kw':
        return 'Detected the keyword "$matched", suggesting an emergency or one-time expense.';
      case 'discretionary_kw':
        return 'Matched merchant keyword "$matched".';
      case 'no_text_income_default':
        return 'No SMS text available — defaulted to income since you marked it a credit.';
      case 'no_text_expense_default':
        return 'No SMS text available — defaulted to discretionary spend.';
      case 'fallback_income_unclassified':
      case 'fallback_expense_unclassified':
        return 'No confident match found — flagged for your review.';
      default:
        return 'Classified using rule: $rule';
    }
  }

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        amount: (json['amount'] as num).toDouble(),
        type: _transactionTypeFromJson(json['type']),
        category: _transactionCategoryFromJson(json['category']),
        description: json['description'],
        merchant: json['merchant'],
        source: json['source'],
        date: DateTime.parse(json['date']),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        txnClass: _transactionClassFromJson(json['txn_class']),
        classificationSource:
            _classificationSourceFromJson(json['classification_source']),
        classificationConfidence:
            (json['classification_confidence'] as num?)?.toDouble() ?? 1.0,
        accountId: json['account_id'],
        rawSms: json['raw_sms'],
        classificationRule: json['classification_rule'],
      );
}

class TransactionCreate {
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final String? merchant;
  final String source;
  final DateTime date;

  TransactionCreate({
    required this.amount,
    this.type = TransactionType.expense,
    this.category = TransactionCategory.other,
    this.description,
    this.merchant,
    this.source = 'manual',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'type': _transactionTypeToJson(type),
        'category': _transactionCategoryToJson(category),
        'description': description,
        'merchant': merchant,
        'source': source,
        'date': date.toIso8601String(),
      };
}
