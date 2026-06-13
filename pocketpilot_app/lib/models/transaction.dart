enum TransactionType { income, expense }
enum TransactionCategory {
  food, transport, housing, entertainment, education, other
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
        type: TransactionType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type']),
        category: TransactionCategory.values.firstWhere(
            (e) => e.toString().split('.').last == json['category']),
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
        'type': type.toString().split('.').last,
        'category': category.toString().split('.').last,
        'description': description,
        'merchant': merchant,
        'source': source,
        'date': date.toIso8601String(),
      };
}