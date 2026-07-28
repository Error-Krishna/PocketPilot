class MonthlyArchive {
  final String id;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final double monthlyBudget;
  final double totalSpent;
  final double totalSaved;
  final double totalAutopays;

  MonthlyArchive({
    required this.id,
    required this.cycleStart,
    required this.cycleEnd,
    required this.monthlyBudget,
    required this.totalSpent,
    required this.totalSaved,
    required this.totalAutopays,
  });

  factory MonthlyArchive.fromJson(Map<String, dynamic> json) => MonthlyArchive(
        id: json['id'],
        cycleStart: DateTime.parse(json['cycleStart']),
        cycleEnd: DateTime.parse(json['cycleEnd']),
        monthlyBudget: (json['monthlyBudget'] as num).toDouble(),
        totalSpent: (json['totalSpent'] as num).toDouble(),
        totalSaved: (json['totalSaved'] as num).toDouble(),
        totalAutopays: (json['totalAutopays'] as num?)?.toDouble() ?? 0,
      );
}
