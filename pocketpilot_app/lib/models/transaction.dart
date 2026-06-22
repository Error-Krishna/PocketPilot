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
  });

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
