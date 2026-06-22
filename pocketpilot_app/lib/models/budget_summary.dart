class BudgetSummary {
  final double monthlyBudget;
  final double totalAutopays;
  final double totalAutopaysDue;
  final double availableBalance;
  final double spentThisMonth;
  final double netIrregularTransactions;
  final double remainingBalance;
  final double dailyLimit;
  final double spentToday;
  final double incomeToday;
  final double savedToday;
  final int remainingDays;

  BudgetSummary({
    required this.monthlyBudget,
    required this.totalAutopays,
    required this.totalAutopaysDue,
    required this.availableBalance,
    required this.spentThisMonth,
    required this.netIrregularTransactions,
    required this.remainingBalance,
    required this.dailyLimit,
    required this.spentToday,
    required this.incomeToday,
    required this.savedToday,
    required this.remainingDays,
  });

  static double _num(Map<String, dynamic> json, String key,
      {double fallback = 0}) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return fallback;
  }

  static int _int(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final value = json[key];
    if (value is num) return value.toInt();
    return fallback;
  }

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
        monthlyBudget: _num(json, 'monthlyBudget'),
        totalAutopays: _num(json, 'totalAutopays',
            fallback: _num(json, 'totalAutopaysDue')),
        totalAutopaysDue: _num(json, 'totalAutopaysDue',
            fallback: _num(json, 'totalAutopays')),
        availableBalance: _num(json, 'availableBalance'),
        spentThisMonth: _num(json, 'spentThisMonth'),
        netIrregularTransactions: _num(json, 'netIrregularTransactions'),
        remainingBalance: _num(json, 'remainingBalance'),
        dailyLimit: _num(json, 'dailyLimit'),
        spentToday: _num(json, 'spentToday'),
        incomeToday: _num(json, 'incomeToday'),
        savedToday: _num(json, 'savedToday'),
        remainingDays: _int(json, 'remainingDays'),
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
        targetDate: json['target_date'] != null
            ? DateTime.parse(json['target_date'])
            : null,
      );
}
