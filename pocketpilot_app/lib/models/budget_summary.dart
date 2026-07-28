class BudgetSummary {
  final double monthlyBudget;
  final double totalAutopays;
  final double totalAutopaysDue;
  final double availableBalance;
  final double spentThisMonth;
  final double savedThisMonth;
  final double netIrregularTransactions;
  final double remainingBalance;
  final double dailyLimit;
  final double spentToday;
  final double incomeToday;
  final double savedToday;
  final int remainingDays;
  final int needsReviewCount;
  final double needsReviewAmount;
  final double lifetimeSavings;
  final DateTime? cycleStart;
  final DateTime? cycleEnd;
  final bool isAwaitingFunds;
  final double? cycleStartingBalance;
  final double? lastKnownBankBalance;
  final DateTime? lastKnownBankBalanceAt;

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
    this.savedThisMonth = 0,
    this.needsReviewCount = 0,
    this.needsReviewAmount = 0,
    this.lifetimeSavings = 0,
    this.cycleStart,
    this.cycleEnd,
    this.isAwaitingFunds = false,
    this.cycleStartingBalance,
    this.lastKnownBankBalance,
    this.lastKnownBankBalanceAt,
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
        savedThisMonth: _num(json, 'savedThisMonth'),
        netIrregularTransactions: _num(json, 'netIrregularTransactions'),
        remainingBalance: _num(json, 'remainingBalance'),
        dailyLimit: _num(json, 'dailyLimit'),
        spentToday: _num(json, 'spentToday'),
        incomeToday: _num(json, 'incomeToday'),
        savedToday: _num(json, 'savedToday'),
        remainingDays: _int(json, 'remainingDays'),
        needsReviewCount: _int(json, 'needsReviewCount'),
        needsReviewAmount: _num(json, 'needsReviewAmount'),
        lifetimeSavings: _num(json, 'lifetimeSavings'),
        cycleStart: json['cycleStart'] != null
            ? DateTime.tryParse(json['cycleStart'])
            : null,
        cycleEnd:
            json['cycleEnd'] != null ? DateTime.tryParse(json['cycleEnd']) : null,
        isAwaitingFunds: json['isAwaitingFunds'] == true,
        cycleStartingBalance: json['cycleStartingBalance'] != null
            ? (json['cycleStartingBalance'] as num).toDouble()
            : null,
        lastKnownBankBalance: json['lastKnownBankBalance'] != null
            ? (json['lastKnownBankBalance'] as num).toDouble()
            : null,
        lastKnownBankBalanceAt: json['lastKnownBankBalanceAt'] != null
            ? DateTime.tryParse(json['lastKnownBankBalanceAt'])
            : null,
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

class SavingsGoalCreate {
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;

  SavingsGoalCreate({
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        if (targetDate != null) 'target_date': targetDate!.toIso8601String(),
      };
}

class SavingsGoalUpdate {
  final String? name;
  final double? targetAmount;
  final double? currentAmount;
  final DateTime? targetDate;

  SavingsGoalUpdate({
    this.name,
    this.targetAmount,
    this.currentAmount,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (targetAmount != null) 'target_amount': targetAmount,
        if (currentAmount != null) 'current_amount': currentAmount,
        if (targetDate != null) 'target_date': targetDate!.toIso8601String(),
      };
}
