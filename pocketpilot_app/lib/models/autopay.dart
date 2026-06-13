enum AutopayFrequency { weekly, biweekly, monthly }

class Autopay {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final AutopayFrequency frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  Autopay({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextRunDate,
    required this.isActive,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Autopay.fromJson(Map<String, dynamic> json) => Autopay(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        frequency: AutopayFrequency.values.firstWhere(
            (e) => e.toString().split('.').last == json['frequency']),
        nextRunDate: DateTime.parse(json['next_run_date']),
        isActive: json['is_active'],
        category: json['category'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}

class AutopayCreate {
  final String name;
  final double amount;
  final AutopayFrequency frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String? category;

  AutopayCreate({
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextRunDate,
    this.isActive = true,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'frequency': frequency.toString().split('.').last,
        'next_run_date': nextRunDate.toIso8601String(),
        'is_active': isActive,
        'category': category,
      };
}

class AutopayUpdate {
  final String? name;
  final double? amount;
  final AutopayFrequency? frequency;
  final DateTime? nextRunDate;
  final bool? isActive;
  final String? category;

  AutopayUpdate({this.name, this.amount, this.frequency, this.nextRunDate, this.isActive, this.category});

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (frequency != null) 'frequency': frequency.toString().split('.').last,
        if (nextRunDate != null) 'next_run_date': nextRunDate!.toIso8601String(),
        if (isActive != null) 'is_active': isActive,
        if (category != null) 'category': category,
      };
}