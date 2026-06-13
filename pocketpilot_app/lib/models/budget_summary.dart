class BudgetSummary {
  final double monthlyBudget;
  final double totalAutopays;
  final double availableBalance;
  final double spentThisMonth;
  final double remainingBalance;
  final double dailyLimit;
  final double spentToday;
  final double savedToday;
  final int remainingDays;

  BudgetSummary({
    required this.monthlyBudget,
    required this.totalAutopays,
    required this.availableBalance,
    required this.spentThisMonth,
    required this.remainingBalance,
    required this.dailyLimit,
    required this.spentToday,
    required this.savedToday,
    required this.remainingDays,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
        monthlyBudget: (json['monthlyBudget'] as num).toDouble(),
        totalAutopays: (json['totalAutopays'] as num).toDouble(),
        availableBalance: (json['availableBalance'] as num).toDouble(),
        spentThisMonth: (json['spentThisMonth'] as num).toDouble(),
        remainingBalance: (json['remainingBalance'] as num).toDouble(),
        dailyLimit: (json['dailyLimit'] as num).toDouble(),
        spentToday: (json['spentToday'] as num).toDouble(),
        savedToday: (json['savedToday'] as num).toDouble(),
        remainingDays: json['remainingDays'],
      );
}

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'],
        name: json['name'],
        targetAmount: (json['target_amount'] as num).toDouble(),
        currentAmount: (json['current_amount'] as num).toDouble(),
        targetDate: json['target_date'] != null ? DateTime.parse(json['target_date']) : null,
      );
}